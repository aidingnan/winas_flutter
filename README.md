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

### 项目逻辑

+ API管理

  - 应用使用的API主要分两套，即云API和口袋网盘API，分别封装在`lib/common/request.dart`和`lib/common/stationApis.dart`

  - 云API都是直接访问'https://aws-cn.aidingnan.com/c/v1'

  - 在同一局域网，客户端会直接通过ip访问口袋网盘，否则就通过云的`pipe`访问口袋网盘。其中`stationApis.dart`中的`command`方法是实现该功能的适配器

  - `lib/common/stationApi.dart`中的注册了对网络变化的监控，当手机网络状态变化时会自动触发设备是否在局域网内的判定

  - 所有的API请求都是使用`dio`库实现的

+ redux 主要代码在`lib/redux`

  - 项目使用redux管理整个应用的状态，使用的库是`flutter_redux`, 使用`redux_persist`实现状态的持久化

+ 登录逻辑 主要代码在`lib/login`

  - 目前支持使用帐户密码和微信(由`fluwx`实现)来登录云帐户，登录后获取访问云api的token，同时获取已绑定的设备列表

  - 登录用户选择的特定口袋网盘，主要是通过云获取口袋网盘的局域网用的token，同时通过调用3001端口的`winasd/info` api 判断设备是否在局域网内

  - 在局域网内则使用ip直接访问，在外网环境则走云的pipe通道访问

+ 文件的上传、下载 主要代码在 `lib/transfer`

  - 上传下载的操作的管理由`lib/transfer/manager.dart`实现

  - 下载文件就是简单的`get`操作

  - 上传文件使用`formdata`格式，需要预先将文件按1G为单位切片，计算每段文件的sha256值和文件整体的fingerprint，由`lib/common/isolate`组件实现

+ 全局底部导航栏 主要代码 `lib/nav`

  - `lib/nav/bottom_navigation.dart`是文件页面全局底部导航栏组件，然后分别可以导航至`云盘`、`相簿`、`设备`、`我的`四个页面

  - `lib/nav/taskFab.dart`中实现了移动、复制任务的显示和管理

+ 云盘页面 主要代码在 `lib/files`

  - `lib/files/file.dart`为入口文件

  - 实现了主要的文件操作，包括选择、列表/网格模式切换、上传、删除、重命名、移动、复制、预览文件、查看属性等

+ 相簿页面 主要代码在 `lib/photos`

  - `lib/photos/photos.dart`为入口文件

  - `lib/photos/backup.dart`实现了对手机相簿的整体备份，其中使用`photo_manager`库实现获取手机的全部照片

  - 照片备份是按照设备为备份单位，备份的文件按年月来归档，目录结构类似于 `Nexus 6P/照片/2019-01`

  - 相簿主要分为三类，全部照片、全部设备、按设备来源的照片

  - 照片缩略图通过`lib/common/taskManager.dart`以队列的形式下载

+ 设备页面 主要代码在 `lib/device`

  - `lib/device/myStation.dart`为入口文件

  - 包括添加新设备和切换设备、设备名称和状态的显示、网络详情、设备信息、系统管理等

+ 我的页面 主要代码在 `lib/user`

  - `lib/user/user.dart`为入口文件

  - 包括个人信息的显示、修改头像、帐户与安全、设置、缓存管理、关于等

+ 图标

  本项目主要使用Flutter自带的图标，其他自定义的图标通过`lib/icons/winas_icons.dart`引入, 由 [fluttericon](http://fluttericon.com/) 自动生成

+ 多语言

  - 使用`flutter_i18n`库来实现，在`assets/locales/`下写好`en.json`、`zh.json`的两个json文件

  - 经过`utils.dart`中的i18n方法封装后使用`i18n('somekey')`的形式获取对应的文本

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

### 相关资料

+ [Flutter 官方文档](https://flutter.dev/docs)

+ [Flutter 中文教程](https://book.flutterchina.club/)

+ [Dart Packages CN镜像](https://pub.flutter-io.cn/)

+ [Flutter issues](https://github.com/flutter/flutter/issues)