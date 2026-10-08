MBP 音量

打开 /Applications/MBP Speaker Volume.app，点击菜单栏的扬声器 + MBP 按钮调节内置扬声器音量。
只修改 BuiltInSpeakerDevice 的输出音量，不切换系统输出，不修改 BlackHole。
面板中的「退出」用于关闭菜单栏按钮；再次打开应用即可恢复。
重新构建：在本目录运行 zsh build.sh。
安装并设置当前用户登录自动启动：在本目录运行 zsh install.sh。
登录启动项：~/Library/LaunchAgents/local.buzz.mbp-speaker-volume.login.plist。
工具只使用本机 CoreAudio，不访问网络、不需要 token。
