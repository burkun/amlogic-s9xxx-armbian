## 一次失败的刷机尝试
### 背景：在淘宝淘了一个“光速盒子”，配置为RK3568,4GB，128GB eMMC，带一个sata3接口，1个千兆网口，两个USB3.0接口。希望刷上ARM变系统

### 步骤：
1. 拆机，观察是否有maskrom触点，没有发现。但是发现有TTL的pin针，存在理论刷机可能性。

2. TTL进入maskrom或者loarder模式
   - 通过USB2TTL工具，接线模式参考in接out，out接in，GD接GD，插入USB口后很容易就能看到启动日志；
   - 启动日志中进入系统无法看到日志，根据日志分析原版系统为安卓系统。不过可以在启动后，按住CTRL+C一直不动，系统会在uboot加载后打断，这个时候就可以进入MaskRom或者loader模式；
   - 进入MaskRom：rockrb，进入loader模式，rockusb，使用RKDEVTOOL（建议使用2.8版本，3.x版本有点问题），安装驱动，就可以看到设备信息了；

3. 刷机镜像构建
   - Fork OPHUB的amlogic-s9xxx-armbian仓库，uboot仓库
   - 此时缺少两个重要文件：uboot.itb, 还有设备树，uboot.itb可以通过拉取RKBIN，Rockchip uboot仓库自己编译，编译时可以在网络上参考编译方式，先编译ubootmemu，配置自己的设备信息，然后再编译uboot bin，然后再编译 make uboot.itb
   - uboot.itb需要一个和ddr内存规格引导的idbloader.img结合才能编译armbian，不过大部分同型号的CPU和DDR内存可以复用，直接用即可。也可以在rkbin里面自己编译出来一个idbloader.img, 具体可以参考网络搜索。
   - 设备树的逆向分析：可以在原始uboot打断后，通过ftb print打印加载到内存中的设备树明文，再结合设备电路板丝印，原件型号，来配置自己的设备树。然后使用dtc和[kernel](https://github.com/ophub/kernel)仓库来编译一个dtb。
   - 此刻会存在：dtb，uboot.itb，idbloader，这几个文件，在ophub的仓库里面配置好自己板子的型号，对应的dtb以及uboot名字，涉及两个仓库[amlogic-s9xxx-armbian](https://github.com/ophub/amlogic-s9xxx-armbian),[uboot](https://github.com/ophub/u-boot),fork到自己的仓库里
   - 编译时要修改git workflow的地址，kernel地址不用改，uboot和armbian拉取地址都要把ophub改成自己git的名字
   - 修改后就可以编译镜像，然后下载下来后，使用rkdevtool，连接loader模式或者maskrom模式的设备，直接刷机，通过ttl可以观察设备的输出。
  
4. 依赖的外部设备
   - 一个双A口的USB线
   - 一个Usb2ttl的线，连接到电脑usb2.0接口下兼容性更好
   - rkchip的波特率一般是1500000，而不是默认值，这点要注意
