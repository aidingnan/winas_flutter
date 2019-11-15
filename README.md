# winas_flutter

基于Flutter开发的口袋网盘移动客户端

+ 项目地址 https://github.com/aidingnan/winas_flutter

+ 本地项目路径
    - linux: /home/lxw/winas_flutter
    - mac: /Users/wisnuc-imac/winas_flutter

### 启动设置

```bash
git clone https://github.com/aidingnan/winas_flutter.git
cd winas_flutter
flutter doctor -v
flutter run
```

### 版本发布

+ Android

证书文件在 `/home/lxw/app_keystore/winas_flutter_keystore.jks`

```
flutter run --release
```

打包后的安装包文件在 `build/app/outputs/apk/release/app-release.apk`，改名后（如KouDaiWangPan-1.8.8.apk）即可发布

+ iOS

使用xcode打开项目，选择目标为`Generic iOS Device`, 点击菜单的`Product` -> `Archive` 然后一步步打包、上传到appstore

之后再到`https://appstoreconnect.apple.com`添加新版本，写描述，提交审核

### 项目结构

+ android

  - android原生项目代码与配置

+ assets

  - i18n相关文件

+ ios

  - ios原生项目代码与配置

+ lib

  - main.dart 程序主入口，读取配置，启动页面

  - login 登录页面

    * login.dart 登录页面的入口
    * accountLogin.dart 用户登录页面
    * stationLogin.dart 设备登录页面
    * stationList.dart 设备列表页面
    * registry.dart 用户注册页面
    * forgetPassword.dart 忘记密码页面
    * scanBleDevice.dart 蓝牙扫描设备
    * configDevice.dart 蓝牙配置设备，包括绑定和设置wifi
    * ble.dart 蓝牙相关接口api
    * confirmFormatDisk.dart 确认格式化磁盘的弹窗
    * confirmUEIP.dart 确认用户使用协议的弹窗
    * loginDeviceFailed.dart 登录失败的弹窗
    * helps.dart 帮助信息

  - nav 底部导航页面

    * bottom_navigation.dart 入口文件
    * delete.dart 删除xcopy任务的弹窗
    * taskFab.dart xcopy任务的FAB
    * taskView.dart xcopy任务的列表页面
    * xcopyTasks.dart xcopy任务的管理

  - files 云盘页面

    * file.dart 通用的文件页面
    * backupView.dart 备份空间页面
    * deleteBackupDrive.dart 删除备份页面
    * delete.dart 删除页面
    * detail.dart 文件详情页面
    * deviceNotOnline.dart 设备不在线的弹窗
    * fileRow.dart 文件列表的每一行的UI
    * newFolder.dart 新建文件夹
    * photo.dart 图片浏览页面
    * rename.dart 重命名
    * renameDriveDialog.dart 重命名备份
    * search.dart 搜索页面的UI
    * tokenExpired.dart token过期的弹窗
    * xcopyDialog.dart 文件拷贝和移动

  - photos 相簿页面

    * photos.dart 相簿页面入口
    * backup.dart 备份功能逻辑代码
    * cupertino_progress_bar.dart 修改的cupertino_progress_bar，用于显示和控制视频播放
    * gridPhoto.dart 预览大图
    * gridVideo.dart 预览视频
    * pageViewer.dart 轮播功能
    * photoItem.dart 单个照片的UI
    * photoList.dart 照片列表UI

  - device 设备页面

    * myStation.dart 设备页面的入口
    * network.dart 网络设置页面
    * deviceInfo.dart 设备信息页面
    * system.dart 系统管理页面
    * confirmDialog.dart 通用的确认弹窗
    * firmwareUpdate.dart 固件升级
    * info.dart 设备信息的Info对象
    * newDeviceName.dart 设备重命名
    * resetDevice.dart 重置设备
    * rootDialog.dart root设备
    * upgradeDialog.dart 系统升级弹窗

  - user 用户页面

    * user.dart 用户页面入口
    * about.dart 关于页面
    * security.dart 帐户与安全页面
    * settings.dart 用户设置页面
    * avatarView.dart 头像显示与设置更新
    * detail.dart 个人信息详情
    * license.dart 用户使用协议的文档
    * newNickName.dart 更新用户昵称
    * resetPhone.dart 修改绑定手机
    * phoneCode.dart 修改绑定手机过程中的验证手机验证码
    * resetPwd.dart 修改密码
    * pwdCode.dart 修改密码过程中的验证手机验证码
    * weChat.dart 微信登录相关

  - transfer 文件传输

    * transfer.dart 文件传输UI
    * manager.dart 文件传输管理逻辑
    * removable.dart 滑动删除组件

  - redux redux相关

    * redux.dart 定义AppState、appReducer、actions和大量基础对象

  - common 通用组件和utils

    * request.dart 云的api集合
    * stationApis.dart 设备的api集合
    * appBarSlivers.dart 适合在CustomScrollView中使用的appBar
    * appConfig.dart 全局通用设备
    * cache.dart 缓存，包括缩略图、预览用的临时文件等
    * eventBus.dart 消息管理
    * intent.dart 处理外部应用发送的文件
    * iPhoneCodeMap.dart iPhone设备名称表
    * isolate.dart 使用子进程处理计算文件hash、上传文件等操作
    * placeHolderImage.dart 占位图
    * renderIcon.dart 处理文件图标
    * taskManager.dart 缩略图下载任务管理
    * utils.dart 各种小工具

  - icons 图标文件，自动生成的，详见 fluttericon.com

  - other 其他文件，实际项目中未用到
