# Trime 键盘开发要点

本文档记录了在开发手心式18键键盘过程中遇到的关键问题及解决方案，供未来开发者参考。

## 1. 智能返回上级键盘

### 问题描述

在多层键盘结构中（如：中文键盘 → 数字键盘 → 返回），希望返回时能自动回到进入前的键盘，而不是固定返回某个键盘。

传统方案需要为每个入口创建不同的子键盘（如 `number_cn`, `number_en`），导致代码冗余。

### 解决方案

使用 `Keyboard_last_lock` + `lock: true` 组合：

```yaml
# 1. 主键盘设置 lock: true
preset_keyboards:
  default:
    lock: true  # 标记为锁定键盘
    # ...

  qwerty26:
    lock: true  # 标记为锁定键盘
    # ...

  number:
    lock: false  # 次级键盘不锁定（或省略）
    # ...

# 2. 定义智能返回键
preset_keys:
  Keyboard_last_lock:
    label: "↩"
    send: Eisu_toggle
    select: .last_lock  # 返回上一个 lock=true 的键盘
```

### 工作原理

- `lock: true` 标记键盘为"主键盘"
- `select: .last_lock` 返回到最近访问的 `lock=true` 键盘
- 次级键盘（`lock: false`）会被跳过

### 已知限制

退出输入法后，下次打开会停留在上次的 lock 键盘，而不是默认键盘。

---

## 2. 18键模糊输入

### 问题描述

实现类似手心输入法的18键布局：
- 点击共键发送左侧字母（触发模糊匹配）
- 左滑发送左侧字母（精确）
- 右滑发送右侧字母（精确）

### 解决方案

**键盘布局配置**：

```yaml
preset_keys:
  key_WE:
    label: "WE"
    send: w  # 点击发送 w

preset_keyboards:
  default:
    keys:
      - {click: key_WE, swipe_left: w, swipe_right: e}
```

**Schema 模糊规则**：

```yaml
# moqi_xh-trime.custom.yaml
patch:
  "speller/algebra/+":
    # WE 共键：允许用 w 匹配 e
    - derive/^e/w/
    - derive/e$/w/
    # RT 共键
    - derive/^t/r/
    - derive/t$/r/
    # ... 其他共键规则
```

### 注意事项

- `derive` 规则作用于词库拼音，不是用户输入
- 滑动精确输入时，模糊候选仍会出现（Rime 层面无法区分输入来源）

---

## 3. 液态键盘（Liquid Keyboard）

### 问题描述

实现可扩展的符号选择器，支持多个分类。

### 解决方案

```yaml
liquid_keyboard:
  keyboards: [剪贴, 表情, 中文标点, 英文标点]  # 键盘列表
  fixed_key_bar:
    position: right  # 固定栏位置
    keys: [BackSpace1, Return1, space1, liquid_keyboard_exit]
  
  # 各分类定义
  剪贴:
    name: 剪贴
    type: CLIPBOARD
  表情:
    name: 表情
    type: SINGLE
    keys: "🙂😂🤣..."
  中文标点:
    name: 中文标点
    type: SINGLE
    keys: ["，", "。", "？", "【】", "《》"]  # 可以是字符串或数组
```

### 入口按键定义

```yaml
preset_keys:
  key_symbol_cn:
    label: "#+="
    send: function
    command: liquid_keyboard
    option: "中文标点"  # 指定打开的键盘名称
```

---

## 4. 分词键实现

### 问题描述

实现分词键：在输入过程中插入分隔符，但不输入任何可见字符。

### 解决方案

使用 `composing` 属性：

```yaml
preset_keyboards:
  default:
    keys:
      - {click: key_fenci, composing: "'"}  # composing 在输入时发送 '

preset_keys:
  key_fenci:
    label: "词'"
    send: Eisu_toggle  # 无输入时不发送任何内容
```

### 工作原理

- `composing: "'"` - 在有输入时发送分隔符 `'`
- `send: Eisu_toggle` - 无输入时执行空操作

---

## 5. Toolbar 配置

### 问题描述

在候选区添加工具栏按钮。

### 解决方案

```yaml
tool_bar:
  button_font: iconfont.ttf
  button_spacing: 5
  buttons:
    - {action: Hide, foreground: {style: "ic@keyboard_close"}}
    - {action: liquid_keyboard_emoji, foreground: {style: "ic@emoticon"}}
    - {action: Keyboard_edit, foreground: {style: "ic@cursor_text"}}
    - {action: F4, foreground: {style: "ic@settings"}}
```

### 可用图标

常用图标样式（需要 iconfont.ttf 支持）：
- `ic@keyboard_close` - 关闭键盘
- `ic@emoticon` - 表情
- `ic@clipboard` - 剪贴板
- `ic@cursor_text` - 光标/编辑
- `ic@settings` - 设置

---

## 6. 按键长按与滑动

### 配置示例

```yaml
preset_keyboards:
  default:
    keys:
      - click: key_space_cn       # 点击动作
        long_click: Keyboard_eng  # 长按动作
        swipe_left: Left          # 左滑动作
        swipe_right: Right        # 右滑动作
        swipe_up: "1"             # 上滑动作
```

### 注意事项

滑动手势在 Trime 源码中处理，YAML 和 Lua 无法修改边界检测逻辑。如果滑动距离过大超出按键边界，可能触发相邻按键。

---

## 7. YAML 锚点与继承

### 使用示例

```yaml
# 定义锚点（基类）
_number_base: &number_base
  author: "Custom"
  name: "数字"
  width: 20
  height: 52

# 使用锚点
preset_keyboards:
  number:
    <<: *number_base  # 继承所有属性
    lock: false       # 覆盖或添加属性
    keys: [...]
```

### 限制

锚点只能继承静态属性，无法实现动态继承（如根据条件选择不同的 keys）。

---

## 8. 保持中英文状态

### 问题描述

切换键盘时保持当前的中英文状态。

### 解决方案

在 `style` 中设置：

```yaml
style:
  reset_ascii_mode: false  # 不重置 ASCII 模式
```

---

## 参考资源

- [Trime 官方文档](https://github.com/osfans/trime)
- [同文风主题](https://github.com/tumuyan/trime-without-CMake)
- [Rime 配置指南](https://github.com/rime/home/wiki)
