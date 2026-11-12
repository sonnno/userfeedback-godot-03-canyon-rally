class_name UIHelper
## 界面工具：加载支持中文的字体并生成统一主题。

static var _font: FontFile = null


## 尝试从系统目录加载中文字体（微软雅黑 / 黑体 / 宋体 / 等线）。
static func get_font() -> Font:
	if _font != null:
		return _font
	var candidates := [
		"C:/Windows/Fonts/msyh.ttc",
		"C:/Windows/Fonts/msyh.ttf",
		"C:/Windows/Fonts/simhei.ttf",
		"C:/Windows/Fonts/simsun.ttc",
		"C:/Windows/Fonts/Deng.ttf",
	]
	for path in candidates:
		if FileAccess.file_exists(path):
			var f := FontFile.new()
			if f.load_dynamic_font(path) == OK:
				_font = f
				return _font
	push_warning("UIHelper: 未找到中文字体，界面中文可能无法显示。")
	return null


## 生成带指定字体大小的主题，供界面控件使用。
static func make_theme(font_size: int) -> Theme:
	var theme := Theme.new()
	var font := get_font()
	if font != null:
		theme.default_font = font
	theme.default_font_size = font_size
	return theme
