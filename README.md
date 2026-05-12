# Snowbreak-AnitAmend


## 使用方法

在任意位置打开 PowerShell，然后执行：

```PowerShell
iwr "https://raw.githubusercontent.com/ahalpha/Snowbreak-AnitAmend/master/install.cmd" -OutFile "install.cmd"; .\install.cmd
```

如果无法访问 GitHub，可以使用镜像代理：

```PowerShell
iwr "https://gh-proxy.org/https://raw.githubusercontent.com/ahalpha/Snowbreak-AnitAmend/master/install.cmd" -OutFile "install.cmd"; .\install.cmd -ughp
```