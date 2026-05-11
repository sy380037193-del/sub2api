# Sub2API GitHub 拉取部署仓库

这个仓库只放本地编译好的部署包，不放服务器密码、不放 .env、不放数据库文件。

当前版本：$ArtifactName

服务器部署方式：

`ash
cd /home/ubuntu/sub2api-release

git pull

bash deploy-current.sh
`

流程是：本地编译 Linux 二进制 -> 把 eleases/*.tar.gz 推送到 GitHub -> 服务器 git pull 拉取包 -> 解压到 /home/ubuntu/sub2api-deploy/local-runtime-build -> 构建本地 Docker 镜像 -> 只重启 sub2api 应用容器。
