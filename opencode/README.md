# OpenCode - dbox 配置

OpenCode 的 Docker 隔离运行封装，同时支持 command 模式和后台 `serve` 模式。

## 使用方法

```bash
# command 模式：在当前目录中启动新容器运行 opencode
d opencode
d opencode --help
d -s opencode            # 进入新容器 shell

# service 模式：启动后台服务容器
d -u opencode
d -d opencode
d -r opencode
```

## 行为说明

`opencode` 配置了：

```bash
COMMAND_CONTAINER=new
```

因此：

- `d opencode` 总是启动新容器，并把当前目录映射进容器
- `d -s opencode` 同样启动新容器进入 shell
- `d -u opencode` 启动后台 `opencode serve`

## 映射规则

`opencode/mappings` 内置：

- OpenCode 本地状态目录映射
- `command:d:{cwd}:{cwd}`，用于 command 模式下在当前项目工作

后台服务需要暴露哪些目录、使用哪个端口，都由你自己在 profile 本地配置中决定，例如：

`profiles/default/mappings.local`:

```text
service:d:/Users/you/Workspace:/Users/you/Workspace
service:p:4096:4096
```

修改后执行 `d -r opencode`，桌面端即可连接 `http://localhost:4096`。

## 首次运行

首次运行时，`pre-exec` 会使用官方安装脚本把 `opencode` 安装到 `$HOME/.local/bin`。

OpenCode 自己的配置和认证状态会持久化到：

- `/home/devuser/.config/opencode`
- `/home/devuser/.local/share/opencode`

## 注意

- service 容器按 `tool + profile` 共享，不按项目隔离
- `opencode serve` 不要求必须存在某个固定的容器目录名；你可以自由决定 service 模式下映射哪些目录
- 如果没有为当前 profile 配置 `service:p:...`，服务仍可启动，但桌面端无法从宿主机连接
