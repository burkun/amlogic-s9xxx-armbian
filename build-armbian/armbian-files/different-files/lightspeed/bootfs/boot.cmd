# boot.cmd
# 请勿手动编辑此文件，修改后需用 mkimage 重新编译为 boot.scr

setenv load_addr "0x39000000"  # 临时加载地址（RK3568 内存地址范围适配）
setenv overlay_error "false"

# 默认参数（会被 armbianEnv.txt 中的配置覆盖）
setenv rootdev "/dev/mmcblk0p1"
setenv verbosity "1"
setenv console "both"
setenv bootlogo "false"
setenv rootfstype "ext4"
setenv rootflags "rw,errors=remount-ro"
setenv docker_optimizations "on"
setenv earlycon "off"

echo "Boot script loaded from ${devtype} ${devnum}"

# 加载 armbianEnv.txt 中的自定义参数
if test -e ${devtype} ${devnum} ${prefix}armbianEnv.txt; then
	load ${devtype} ${devnum} ${load_addr} ${prefix}armbianEnv.txt
	env import -t ${load_addr} ${filesize}
fi

# 处理启动 Logo（如需禁用则保持默认）
if test "${logo}" = "disabled"; then setenv logo "logo.nologo"; fi

# 配置控制台参数（结合 serial/display）
if test "${console}" = "display" || test "${console}" = "both"; then setenv consoleargs "console=tty1"; fi
if test "${console}" = "serial" || test "${console}" = "both"; then setenv consoleargs "${consoleargs} console=ttyS2,1500000"; fi  # 确保串口参数正确
if test "${earlycon}" = "on"; then setenv consoleargs "${earlyconargs} ${consoleargs}"; fi  # 启用早期控制台
if test "${bootlogo}" = "true"; then setenv consoleargs "bootsplash.bootfile=bootsplash.armbian ${consoleargs}"; fi

# 获取启动设备的 PARTUUID（增强兼容性）
if test "${devtype}" = "mmc"; then part uuid mmc ${devnum}:1 partuuid; fi

# 组合最终启动参数（bootargs）
setenv bootargs "root=${rootdev} rootwait rootfstype=${rootfstype} rootflags=${rootflags} ${consoleargs} consoleblank=0 loglevel=${verbosity} usb-storage.quirks=${usbstoragequirks} ${extraargs} ${extraboardargs}"

# 启用 Docker 优化参数
if test "${docker_optimizations}" = "on"; then setenv bootargs "${bootargs} cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1"; fi

# 加载内核、初始化ramdisk、设备树（路径需与 Armbian 镜像一致）
load ${devtype} ${devnum} ${ramdisk_addr_r} ${prefix}uInitrd  # 加载初始化ramdisk
load ${devtype} ${devnum} ${kernel_addr_r} ${prefix}Image      # 加载内核（Armbian 通常用 Image 作为内核文件名）
load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}  # 加载设备树（路径对应 armbianEnv.txt 中的 fdtfile）

# 应用设备树overlay（官方+用户自定义）
fdt addr ${fdt_addr_r}
fdt resize 65536
for overlay_file in ${overlays}; do
	if load ${devtype} ${devnum} ${load_addr} ${prefix}dtb/rockchip/overlay/${overlay_prefix}-${overlay_file}.dtbo; then
		echo "Applying kernel provided DT overlay ${overlay_prefix}-${overlay_file}.dtbo"
		fdt apply ${load_addr} || setenv overlay_error "true"
	fi
done
for overlay_file in ${user_overlays}; do
	if load ${devtype} ${devnum} ${load_addr} ${prefix}overlay-user/${overlay_file}.dtbo; then
		echo "Applying user provided DT overlay ${overlay_file}.dtbo"
		fdt apply ${load_addr} || setenv overlay_error "true"
	fi
done

# 若overlay应用失败，恢复原始设备树
if test "${overlay_error}" = "true"; then
	echo "Error applying DT overlays, restoring original DT"
	load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtb/${fdtfile}
else
	# 应用设备树修复脚本（若存在）
	if load ${devtype} ${devnum} ${load_addr} ${prefix}dtb/rockchip/overlay/${overlay_prefix}-fixup.scr; then
		echo "Applying kernel provided DT fixup script (${overlay_prefix}-fixup.scr)"
		source ${load_addr}
	fi
	if test -e ${devtype} ${devnum} ${prefix}fixup.scr; then
		load ${devtype} ${devnum} ${load_addr} ${prefix}fixup.scr
		echo "Applying user provided fixup script (fixup.scr)"
		source ${load_addr}
	fi
fi

# 启动内核（arm64 架构用 booti）
booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}

# mkimage -C none -A arm -T script -n "Armbian RK3568 EVB Boot Script" -d boot.cmd boot.scr