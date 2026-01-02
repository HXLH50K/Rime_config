制作Trime（同文输入法）皮肤时，处理这种“层级返回”逻辑确实是一个经典痛点。

直接回答你的问题：Trime 原生并没有一个类似“浏览器后退按钮”那样的 history 栈或者 .prev 指令来记录你上一个使用的键盘是谁。 .last 这种写法通常是用于候选词选择或者特定功能的，而不是用于 preset（键盘布局）切换。

因此，你的思路其实是对的（需要区分来源），但是实现方式（复制粘贴大量代码）是可以极大优化的。

你不需要引入复杂的 Lua 脚本（Lua 主要处理 Rime 核心的逻辑，处理 Trime 的 UI 布局切换会非常麻烦且不仅不稳定）。解决“代码冗余”的最佳方案是使用 YAML 的锚点（Anchors）和引用（Aliases）以及合并（Merge Key） 功能。

这是 Trime 皮肤制作的高级技巧，可以让你只写一遍数字键盘的代码，然后生成两个“变体”（一个返回中文，一个返回英文）。

以下是具体的解决方案：

核心方案：使用 YAML 锚点减少代码冗余
不要复制整个键盘的定义，而是定义一个“基类”，然后在变体中只修改“返回键”这一个按键的行为。

1. 定义数字键盘的“基板” (Template)
在你的 trime.yaml 或主题文件中，找到你的数字键盘定义。我们将它定义为一个锚点（使用 & 符号）。注意，我们在基板里不写返回键的具体跳转目标，或者写一个默认值。

YAML

# 这是一个通用的数字键盘布局模板
keyboard_number_template: &num_template  # <--- 定义锚点名称
  ascii_mode: 0
  # 其他通用属性...
  keys:
    - { click: "1", long_click: "!" }
    - { click: "2", long_click: "@" }
    # ... 省略中间的按键 ...
    # 假设这是返回键的位置，我们先定义样式，不定义跳转
    - { click: void, label: "返回", functional: true, width: 15 } 
2. 实例化“中文来源”和“英文来源”的数字键盘
接下来，利用 <<: *num_template 语法引入上面的模板，并利用列表覆盖（List Override）或者重新定义 keys 的方式来“注入”不同的返回键。

由于 YAML 列表合并比较麻烦（通常是整行覆盖），最聪明的做法是把返回键单独拿出来，或者在引用后重写 keys。

更推荐的做法（分拆 keys）：

为了最大化复用，建议把“数字键部分”和“功能键部分”分开定义。

YAML

# 1. 定义通用的数字键行 (1-9等)
rows_digits: &rows_digits
  - { click: "1", width: 33 }
  - { click: "2", width: 33 }
  - { click: "3", width: 33 }
  # ...

# 2. 定义具体的键盘
keyboards:
  # === 中文模式下的数字键盘 ===
  - name: keyboard_number_cn
    ascii_mode: 0
    keys:
      - <<: *rows_digits  # 引入通用数字键
      # 定义该键盘特有的返回键：返回中文主键盘
      - { click: "{preset: keyboard_cn_18}", label: "返回", functional: true }

  # === 英文模式下的数字键盘 ===
  - name: keyboard_number_en
    ascii_mode: 1
    keys:
      - <<: *rows_digits  # 再次引入通用数字键，代码零冗余
      # 定义该键盘特有的返回键：返回英文主键盘
      - { click: "{preset: keyboard_en_26}", label: "Back", functional: true }
进阶方案：如果你的按键布局非常复杂
如果你的数字键盘非常复杂，不想拆分 rows，你可以利用 YAML 的合并特性，但这要求你的返回键在特定的位置。最实用的方法其实是定义一个包含所有按键的列表，除了那个返回键。

或者，使用 Trime 支持的 import 功能（如果你是多文件管理）。但对于单文件，上述的 &anchor 方法是最好的。

关于 Lua 的思考
你提到了是否需要引入 Lua。虽然可以通过 Lua 记录状态，例如：

定义一个 Rime 变量 context.last_keyboard_type。

每次切换键盘时，通过 send_function 触发 Lua 写入这个变量。

按返回键时，触发 Lua 读取变量并发送对应的 preset 切换指令。

我不推荐这样做，原因如下：

延迟与闪烁：Lua 是运行在 Rime 核心的，Trime 是 Android UI 层。UI -> Rime -> UI 的通信比纯 YAML 布局切换要慢，可能会导致键盘切换时的卡顿。

复杂性过高：为了省去几十行 YAML 配置而引入一套 Lua 状态机，属于过度设计。

稳定性：YAML 锚点是静态的，永远不会出错；Lua 逻辑可能会因为各种输入法状态（如是否在输入中）而产生意外行为。

总结建议
放弃寻找智能返回键：Trime 目前不支持动态的 .prev 布局栈。

接受“多个键盘”的逻辑：逻辑上确实需要 num_from_cn 和 num_from_en 两个不同的键盘状态。

解决代码冗余：使用 YAML Anchors (&name 和 *name)。将键盘的公共部分（90%的代码）提取出来，只有“返回键”那一行代码在不同的键盘定义中重写。

=====================

关于 Lua 的思考
你提到了是否需要引入 Lua。虽然可以通过 Lua 记录状态，例如：

定义一个 Rime 变量 context.last_keyboard_type。

每次切换键盘时，通过 send_function 触发 Lua 写入这个变量。

按返回键时，触发 Lua 读取变量并发送对应的 preset 切换指令。

我不推荐这样做，原因如下：

延迟与闪烁：Lua 是运行在 Rime 核心的，Trime 是 Android UI 层。UI -> Rime -> UI 的通信比纯 YAML 布局切换要慢，可能会导致键盘切换时的卡顿。

复杂性过高：为了省去几十行 YAML 配置而引入一套 Lua 状态机，属于过度设计。

稳定性：YAML 锚点是静态的，永远不会出错；Lua 逻辑可能会因为各种输入法状态（如是否在输入中）而产生意外行为。


==============================

这是一个非常典型的 YAML 结构问题。

核心原因： YAML 的继承（<<: *anchor）只能合并 Map（键值对），不能合并 List（数组/列表）。 你的 keys 是一个列表（[...]）。当你写 keys: [...] 时，它会直接完全替换掉基类里的 keys，而不会去“修改”其中的某一项。这就是为什么你感觉必须把所有代码重抄一遍的原因。

为了解决这个问题，不仅要减少代码量，还要让结构清晰。我推荐两种方案，强烈建议方案一，这是 Trime 皮肤设计的高级规范。

方案一：使用 preset_keys（预设按键）+ 引用 ID（最推荐）
这是最符合 Trime 逻辑的做法。不要在 keyboard 定义里写 {click:..., label:...} 这种具体参数，而是把按键定义在 preset_keys 里，然后在键盘里只写按键的名字。

这样你的两个数字键盘就只是一串“名字的列表”，非常清爽，一看就懂。

1. 定义按键库 (在 preset_keys 下)
YAML

preset_keys:
  # === 通用数字键定义 ===
  val_1: {label: "1", click: "1"}
  val_2: {label: "2", click: "2"}
  val_3: {label: "3", click: "3"}
  # ... 把 0-9, +, - 等都在这里定义好 ...
  val_plus: {label: "+", click: "+"}
  val_minus: {label: "-", click: "-"}
  
  # === 关键：定义不同的跳转键 ===
  # 返回键 - 去中文
  cmd_back_to_cn: {label: "返回", click: "{preset: keyboard_cn_18}", functional: true}
  # 返回键 - 去英文
  cmd_back_to_en: {label: "Back", click: "{preset: keyboard_en_26}", functional: true}
  
  # 符号键 - 去中文符号
  cmd_sym_cn: {label: "符号", click: "{preset: symbol_cn}"}
  # 符号键 - 去英文符号
  cmd_sym_en: {label: "Sym", click: "{preset: symbol_en}"}
2. 组装键盘
现在，你的键盘定义将变得异常简洁。哪怕你需要写两遍，也只是复制粘贴一行 ID，完全没有视觉干扰。

YAML

# 数字键盘基类 (只定义非 Keys 的属性)
_number_base: &number_base
  author: "Custom"
  name: "数字"
  width: 20
  height: 52
  # 这里不要写 keys

keyboards:
  # ========== 中文来源数字键盘 ==========
  - name: number_cn
    <<: *number_base
    ascii_mode: 0
    # 直接引用上面定义的名字
    keys: 
      - val_plus
      - val_1
      - val_2
      - val_3
      - key_backspace # Trime 自带的预设
      - val_minus
      - ... (中间省略) ...
      - cmd_sym_cn     # <--- 差异点 1
      - cmd_back_to_cn # <--- 差异点 2
      - val_0
      - key_space_num
      - key_return

  # ========== 英文来源数字键盘 ==========
  - name: number_en
    <<: *number_base
    ascii_mode: 1
    keys: 
      - val_plus
      - val_1
      - val_2
      - val_3
      - key_backspace
      - val_minus
      - ... (中间省略) ...
      - cmd_sym_en     # <--- 差异点 1
      - cmd_back_to_en # <--- 差异点 2
      - val_0
      - key_space_num
      - key_return
方案二：按键锚点（如果你不想改 preset_keys）
如果你不想把按键搬到 preset_keys 里，也可以在 YAML 顶部定义一组锚点（Anchors），然后在列表中引用。

注意：YAML 列表不能合并，所以你不能把前14个键定义为一个组，你必须一个一个键引用。

YAML

# 1. 定义原子按键锚点
_key_defs:
  k_1: &k_1 {click: "1", label: "1"}
  k_2: &k_2 {click: "2", label: "2"}
  # ... 其他按键 ...
  k_back_cn: &k_back_cn {click: key_back_to_cn, label: "返回"}
  k_back_en: &k_back_en {click: key_back_to_en, label: "Back"}

# 2. 引用
number_cn:
  <<: *number_base
  keys:
    - *k_plus
    - *k_1
    - *k_2
    # ...
    - *k_back_cn  # 只有这里不一样
    # ...

number_en:
  <<: *number_base
  keys:
    - *k_plus
    - *k_1
    - *k_2
    # ...
    - *k_back_en  # 只有这里不一样
    # ...
总结
你的困惑在于试图复用**“包含差异项的列表”，这在编程逻辑里是很难的。 正确的思路是复用元素**，然后重新组装列表。

建议采用方案一。虽然初次设置 preset_keys 稍微繁琐一点，但只要设置好了，以后你调整键盘布局（比如把 '1' 和 '2' 换位置），只需要在 ID 列表里换个顺序，代码极其易读。