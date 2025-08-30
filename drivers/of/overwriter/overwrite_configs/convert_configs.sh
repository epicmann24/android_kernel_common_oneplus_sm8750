#!/bin/bash
srctree=$(pwd)

# Add struct overwrite_config_group
temp=""
temp+="struct overwrite_config_group {\n    const char *prefix;\n    const char *const *values;\n    int count;\n};\n\n"

# 存储所有已处理的前缀和对应的配置行，以便生成组结构
declare -A config_map
declare -A config_counts

# 辅助函数：读取文件并将行添加到对应的 map 条目，处理换行符
function process_file() {
    local prefix=$1
    local file=$2
    # 使用 tr 移除 \r（Windows 换行符中的 CR）
    while IFS= read -r line; do
        # 移除行尾的 \r（如果存在）
        line=$(echo "$line" | tr -d '\r')
        if [ -n "$line" ]; then
            # 存储不带前缀的行
            config_map[$prefix]+="\"$line\","
            ((config_counts[$prefix]++))
        fi
    done < <(tr -d '\r' < "$file") # 预处理输入文件，移除 \r
}

# 处理 common 文件夹中的配置文件
common_dir="$srctree/drivers/of/overwriter/overwrite_configs/common"
if [ -d "$common_dir" ]; then
    for file in "$common_dir"/*.conf; do
        if [ -f "$file" ]; then
            process_file "common" "$file"
        fi
    done
fi

# 处理数字命名的机型代号文件夹
config_base_dir="$srctree/drivers/of/overwriter/overwrite_configs"
for model_dir in "$config_base_dir"/[0-9]*; do
    if [ -d "$model_dir" ]; then
        model_prefix=$(basename "$model_dir")
        for file in "$model_dir"/*.conf; do
            if [ -f "$file" ]; then
                process_file "$model_prefix" "$file"
            fi
        done
    fi
done

# --- 在生成 overwrite_config_groups 之前，先生成所有的 values 数组 ---
for prefix in "${!config_map[@]}"; do
    values_str="${config_map[$prefix]}"
    
    # 构造 C 语言中合法的变量名
    c_var_name="${prefix}"
    if [[ "$prefix" =~ ^[0-9] ]]; then
        c_var_name="model_${prefix}" # 如果前缀是数字开头，添加 "model_" 前缀
    fi

    # 为每个前缀生成一个独立的字符串数组
    temp+="static const char *const ${c_var_name}_values[] = {\n"
    # 移除最后一个逗号（如果有的话）
    if [ -n "$values_str" ]; then
        temp+="    ${values_str%,}"
    fi
    temp+="};"
    temp+="\n\n"
done

group_count=0

temp+="\nconst struct overwrite_config_group overwrite_config_groups[] = {\n"

for prefix in "${!config_map[@]}"; do
    values_count="${config_counts[$prefix]:-0}" # 如果没有配置，默认为0

    # 构造 C 语言中合法的变量名，与上面保持一致
    c_var_name="${prefix}"
    if [[ "$prefix" =~ ^[0-9] ]]; then
        c_var_name="model_${prefix}"
    fi

    # 将该前缀的组添加到主数组中
    temp+="    { .prefix = \"$prefix\", .values = ${c_var_name}_values, .count = $values_count },\n"
    ((group_count++))
done

temp+="};\n\nconst int overwrite_config_group_count = $group_count;"

sed -i "/#define PATCH_TAG \"overwrite_configs\"/a$temp" "$srctree/drivers/of/overwriter/overwrite_config_loader.c"
