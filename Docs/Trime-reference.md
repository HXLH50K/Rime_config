# Trime 配置参考

本文档只记录当前主题仍在使用、且容易踩坑的配置模式。

## 主键盘与返回

主键盘设置 `lock: true`：

```yaml
preset_keyboards:
  default:
    ascii_mode: 0
    lock: true
  qwerty26:
    ascii_mode: 1
    lock: true
```

子键盘设置 `lock: false`，通过 `.last_lock` 返回：

```yaml
preset_keys:
  to_lastlock_keyboard:
    label: "◁"
    send: Eisu_toggle
    select: .last_lock
```

当前切换关系：

```text
中文 -> 英文 / 数字 / 符号 / 编辑
英文 -> 中文 / 数字 / 符号 / 编辑
数字、编辑 -> 最近的中文或英文主键盘
液态键盘 -> 打开前的键盘
```

数字键盘布局：

```text
+  1 2 3  BackSpace
-  4 5 6  .
@  7 8 9  :
符号  返回  0  空格  回车
```

数字键盘的“返回”通过 `.last_lock` 回到进入前的中文或英文主键盘；符号键盘退出时回到打开它的主键盘或数字键盘。

## 中英文状态

目标键盘的 `ascii_mode` 决定中英文状态。避免在显示键盘时额外重置：

```yaml
style:
  reset_ascii_mode: false

preset_keyboards:
  default:
    reset_ascii_mode: false
```

## 共键与滑动精确输入

点击发送小写，滑动发送大写标记：

```yaml
- click: key_WE
  swipe_left: W
  swipe_right: E

preset_keys:
  key_WE:
    label: "WE"
    send: w
```

大写由 Lua Processor 转成小写并记录精确位置。

## 仅在输入态生效的按键

`composing` 可让按键只在存在组合输入时发送动作：

```yaml
- click: VoidSymbol
  composing: key_auxiliary
  swipe_up: key_fenci
  send_bindings: false
```

当前点击发送 `[`，上滑发送分词符 `'`。

## 液态键盘

入口：

```yaml
to_symbol_liquid_keyboard:
  label: "#+="
  functional: true
  send: function
  command: liquid_keyboard
  option: "常用"
```

固定栏通过 `liquid_keyboard/fixed_key_bar` 配置，退出动作使用 `option: "-1"`。

## YAML 锚点

重复的静态键盘属性可使用 YAML 锚点：

```yaml
_number_base: &number_base
  width: 20
  height: 59

preset_keyboards:
  number:
    <<: *number_base
```

锚点不能表达动态条件。

## 工具栏

候选区工具栏使用 `tool_bar/buttons`。按钮的 `action` 必须对应 `preset_keys` 中的动作名。

## 调试原则

- Trime 部署是异步的；广播成功不等于编译已经完成。
- 修改 schema/algebra 后应删除对应 schema 和 prism 构建产物。
- 修改主题后应删除对应 `.trime.yaml` 构建产物。
- 日志默认不显示 `context.input` 或候选区间；复杂 Lua 问题可加入范围受限的临时 `log.info`，定位后必须删除。
- 遇到窗口自动展开、布局消失等问题，应先查 Trime UI 状态机；Rime option 不一定控制 Android 窗口状态。