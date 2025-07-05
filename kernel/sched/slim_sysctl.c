/* SPDX-License-Identifier: GPL-2.0 */

#include "slim.h"

unsigned int highres_tick_ctrl = true;
unsigned int highres_tick_ctrl_dbg;

#define HIGHRES_TICK_CTRL	"highres_tick_ctrl"
#define HIGHRES_TICK_CTRL_DBG	"highres_tick_ctrl_dbg"

#define SLIM_SCHED_DIR		"slim_sched"


noinline int tracing_mark_write(const char *buf)
{
        trace_printk(buf);
        return 0;
}


static char *files_name[] = {
	HIGHRES_TICK_CTRL,
	HIGHRES_TICK_CTRL_DBG,
};

static int *file_data[] = {
	&highres_tick_ctrl,
	&highres_tick_ctrl_dbg,
};

static ssize_t slim_common_write(struct file *file, const char __user *buf,
                               size_t count, loff_t *ppos)
{
        int *pval = (int *)pde_data(file_inode(file));
        char kbuf[5] = {0};
        int err;

        if (count >= 5)
                return -EFAULT;

        if (copy_from_user(kbuf, buf, count)) {
                pr_err("slim_sched : Failed to copy_from_user\n");
                return -EFAULT;
        }
        err = kstrtoint(strstrip(kbuf), 0, pval);
        if (err < 0) {
                pr_err("slim_sched: Failed to exec kstrtoint\n");
                return -EFAULT;
        }

        return count;
}

static int slim_common_show(struct seq_file *m, void *v)
{
        seq_printf(m, "%d\n", *(int*) m->private);
        return 0;
}

static int slim_common_open(struct inode *inode, struct file *file)
{
        return single_open(file, slim_common_show, pde_data(inode));
}

static const struct proc_ops common_proc_ops = {
        .proc_open              = slim_common_open,
        .proc_write             = slim_common_write,
        .proc_read              = seq_read,
        .proc_lseek             = seq_lseek,
        .proc_release           = single_release,
};

struct proc_dir_entry *slim_dir;
EXPORT_SYMBOL(slim_dir);

static int __init slim_sysfs_init(void)
{
	int i;
	slim_dir = proc_mkdir(SLIM_SCHED_DIR, NULL);
	if (slim_dir) {
		for (i = 0; i < ARRAY_SIZE(files_name); i++) {
			proc_create_data(files_name[i], S_IRUGO | S_IWUGO,
					slim_dir, &common_proc_ops, file_data[i]);
		}
	}
	return 0;
}

__initcall(slim_sysfs_init);

