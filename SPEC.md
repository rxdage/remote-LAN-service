# remote-LAN-service — 产品设计 spec(v0 草案)

> 状态:设计草案,待评审。本文件只定"做什么/什么结构/装机界面长什么样",不含实现。
> 定位:把 `resilient-remote-access` 里验证过的自建远程接入能力,**产品化**成一套
> 别人(同事/客户)能在自己云服务器 + 自己机器上,**按需勾选、向导式装好**的服务。

---

## 1. 这是什么 / 不是什么

**是**:一套"自己搭、自己拥有"的远程接入方案的**安装与配置产品**。客户提供自己的云服务器和终端机器,通过一个**向导式安装器**选择要哪一档、开哪些通道,自动装好服务端 + 客户端。

**不是**:
- ❌ 不是托管服务(不替客户跑服务器、不碰客户数据);
- ❌ 不含 `agent-bus`(AI 编队中枢)——客户只要 RustDesk 远程桌面;
- ❌ 不含 `remote-hq-design` 的入网/CA/gap4(那是作者私有车队的信任体系);
- ❌ 不含作者本人的真实 IP/密钥/网络号(产品是模板,真值客户自备)。

**与现有仓的关系**:
- `resilient-remote-access` 继续作**作者私人 fleet 仓**(作者自己的机器靠它的 line-panel 自动更新,不能动)。
- 本仓从它**挑好料**(line-panel、RUNBOOK 精华、deploy 脚本)重组为产品,两边靠 cherry-pick 同步。line-panel 暂时两份维护,等真痛了再抽公共。

---

## 2. 三档 = 模块叠加(A ⊂ B ⊂ C)

核心理念:**不是三个割裂产品,是一条叠加阶梯**,客户从 A 起步、加模块即可长到 B/C,不推倒重来 → 天然的升级/加价路径。

| 档 | 装什么 | 连接方式 | 卖点 | 服务器数 |
|---|---|---|---|---|
| **A 极简** | 仅 `rustdesk-server`(hbbs+hbbr) | 按 RustDesk **ID** 连,服务器居中撮合(UDP 打洞直连,打不通走中继) | 一台服务器、10 分钟搭好、只为自建 RustDesk 不依赖公有云 | 1 |
| **B 多线** | A + 可**勾选**:WireGuard hub / ZeroTier moon / Headscale | 增加"填对方内网 IP 直连"——不经任何信令服务器;可多条独立隧道 | 直连内网(可跑 RDP/SMB/SSH 任何服务)+ 多路抗断 | 1 |
| **C 双服** | B + 第二台异地服务器(WG 备用 hub + 备用 moon + hbbs 迁备机) | 主服务器整机挂掉,备用线路零切换仍在 | 无单点故障 | 2 |

### 2.1 附录:为什么需要 B 的 WG(A 已能用 RustDesk,为何还要 WG)——写进客户文档

- **A(自建 hbbs 按 ID 连)**:服务器跑 RustDesk 专用信令,按 ID 撮合;能用,但①依赖 hbbs 活着来撮合 ②只有这一条路 ③只能跑 RustDesk。
- **B(WG 直连 IP)**:服务器跑通用 WireGuard,机器进同一虚拟局域网,RustDesk 填内网 IP 直连、**完全不碰任何 RustDesk 服务器**。WG 的价值不是"让 RustDesk 能用",而是:① 一张能跑**任何**服务的通用内网;② **多条可切换的独立传输**做抗断;③ 发起连接不依赖信令服务器。代价:每台要配 WG 密钥。
- 一句话给客户:**只想自建 RustDesk → A 够了;要抗断/要跑别的服务/要多路冗余 → 上 B。**

---

## 3. 安装器:向导式,像产品安装包(核心诉求)

客户体验必须**像装一个成品软件**,不是读脚本文档。两端两平台:

### 3.1 平台矩阵

| | 服务器端(装 hbbs/WG/ZT/headscale) | 客户端(终端机,装 RustDesk 客户端 + 可选 WG/ZT 接入 + Line Panel) |
|---|---|---|
| **Linux** | 主战场(云服务器基本是 Linux):**交互式 TUI 向导**(纯 shell/whiptail,无依赖) | 少数(Linux 桌面):同 TUI |
| **Windows** | 少见(Windows 服务器):PowerShell 向导 | 主战场:**GUI 安装向导(.exe)**,像 NSIS/Inno 那种下一步下一步 |

### 3.2 安装器要走的向导流程(不论平台,同一逻辑)

```
① 角色     : 这台是【服务器】还是【客户端/终端机】?
② 档位     : A 极简 / B 多线 / C 双服   (选 B/C 时继续 ③)
③ 模块勾选 : [x] RustDesk 服务(A 必选)
             [ ] WireGuard hub        (B+)
             [ ] ZeroTier moon        (B+)
             [ ] Headscale 自动入网   (B+,可选)
             [ ] 第二服务器/备份       (C)
④ 填值     : 服务器公网 IP、要用的端口、(客户端)对端地址/ID
             —— 能自动探测的自动带默认(如本机公网 IP、闲置端口)
⑤ 预检     : 检查端口占用/防火墙/依赖,列出"将要做的事" → 用户确认
⑥ 执行     : 只跑选中模块,全程进度 + 日志;失败可回滚
⑦ 完成     : 打印/展示"下一步"(客户端如何连、如何验证、云安全组要开哪些口)
```

### 3.3 三种安装器形态(共享同一套模块脚本 + 同一份配置产物)

关键设计:**三个前端,一个后端**。向导(TUI/GUI/应答文件)只负责"问答→生成一份 `install-plan.json`",真正干活的是平台无关的**模块执行器**读这份 plan 跑。这样加一档/改一个模块,三个前端都不用动。

- **Linux TUI**:`install.sh` → `whiptail`/`dialog` 菜单(无则降级纯文本问答)→ 生成 plan → 执行器(bash)跑选中模块。
- **Windows GUI**:`.exe`(WPF 向导,或 line-panel 同款 PowerShell+WPF 打包 ps2exe)→ 生成 plan → 执行器(PowerShell)跑选中模块。
- **无人值守/批量**:直接喂一份 `install-plan.json`(`install.sh --plan plan.json` / `installer.exe /plan=...`),跳过向导 —— 给进阶客户和你自己批量部署用。

### 3.4 安装器不做的(安全红线,继承自现有规范)

- ❌ 不替客户生成/传输私钥:WG 私钥在**本机**生成,只上送公钥(P5)。
- ❌ 不把任何密钥写进仓/日志/plan 的可提交部分(plan 里 secret 段单独、gitignore)。
- ❌ 云安全组不替客户改(没有其云 API 凭据)——安装器只**打印该开哪些端口**,客户自己在控制台开。
- ❌ 不碰客户既有服务:装前预检端口占用,冲突则报错让用户选,不静默覆盖。

---

## 4. 仓库 / 程序结构

```
remote-LAN-service/
  installer/
    install.sh                  # Linux 入口:TUI 向导 → plan → 执行
    install.ps1                 # Windows 入口(客户端/Win服务器):向导 → plan → 执行
    gui/                        # Windows GUI 向导源(WPF),ps2exe 打包成 setup.exe
    plan.schema.json            # install-plan.json 的结构定义(三前端共同产物)
    modules/                    # 平台无关"模块",每个自带 up/down/preflight/verify
      rustdesk-server/          #   A
      wireguard-hub/            #   B
      zerotier-moon/            #   B
      headscale/                #   B(可选)
      second-region/            #   C
      client-rustdesk/          #   客户端:装 RustDesk 客户端 + 指向服务器
      client-overlay/           #   客户端:接入 WG/ZT(B+)
      line-panel/               #   客户端:GUI(从 resilient-remote-access 挑来)
  config/
    install-plan.example.json   # 一份填好的样例(A/B/C 各一段注释)
    customer.example.env        # 真值模板(gitignored 后缀)
  docs/
    quickstart-A.md             # 极简:一台服务器 + 按 ID 连
    quickstart-B.md             # 多线:加 WG/ZT,直连内网
    quickstart-C.md             # 双服:异地备份
    why-wireguard.md            # §2.1 那段:A vs B 的区别
    RUNBOOK.md                  # 运维/排障(从 resilient-remote-access 精简挑来)
    SECURITY.md                 # 私钥不过网等红线(继承现有规范)
  scripts/
    build-windows-exe.ps1       # ps2exe 打包 setup.exe
    release.sh                  # 版本/校验和/发布产物(客户从这里下)
  LICENSE                       # ⚠️ 见 §6,商用授权是拦路点,待定
  README.md
```

设计要点:
- **模块自描述**:每个 `modules/<x>/` 提供统一四个动作 `preflight / up / down / verify`,执行器按 plan 里勾选的模块依次调 —— "选择增加哪些"在架构层面天然成立,加新通道=加一个模块目录。
- 你现有的 `deploy-wg-hub.sh` / `deploy-moon.sh` / gap4 的 `mod-*.ps1` 就是这些模块的雏形,产品化=抽出来去掉 fleet 专属(入网/CA)、包统一接口。
- **一份 plan 贯穿始终**:向导产出它、执行器消费它、`verify` 依据它、无人值守直接喂它、排障时它就是"这台装了啥"的事实源。

---

## 5. 里程碑(建议顺序,细节等本 spec 评审后再拆)

1. **M0 骨架**:仓结构 + plan.schema + 一个跑得起来的 Linux TUI(只有 A 档 rustdesk-server 一个模块)——最小可用,先让第一个客户用 A 跑起来。
2. **M1 B 档模块**:WG hub / ZT moon 模块 + 客户端 overlay 接入 + Line Panel 集成。
3. **M2 Windows GUI setup.exe**:WPF 向导打包,客户端主战场。
4. **M3 C 档**:第二服务器 + 备份/切换 + 双服 verify。
5. **M4 打磨**:无人值守 plan、release 产物+校验和、quickstart 三件套定稿。

---

## 6. 待你(机主)拍板的商业/法务点(我不替你定)

1. **License**:现有 `resilient-remote-access` 是 PolyForm **Noncommercial**(禁商用)。产品要收费的话必须换 license,或采"代码开源/免费、只对部署+支持服务收费"的模式。**"免费第一个客户"可先口头授权**,但收费前必须理清。
2. **line-panel 双份维护**:短期接受产品仓与 fleet 仓各一份,等维护痛了再抽公共库。
3. **收费/产品化触发点**:等有**真实付费客户**、真实痛点驱动时再往上做客户配置管理/多客户运维,别现在为一个试点过度设计。
4. **第一个客户(同事)先跑 A**:用他踩到的痛点决定 M1 之后往哪长,而不是提前全押。

---

## 7. 明确不做(防膨胀)

- 不做多租户/客户管理后台(不是托管服务)。
- 不做自动改云安全组(无凭据,只提示)。
- 不并入 agent-bus / gap4 / 作者私有 infra。
- 不在 M0 就三平台全铺——先 Linux 服务器 TUI + A 档跑通,再按里程碑长。
