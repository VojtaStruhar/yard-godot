# SPDX-FileCopyrightText: 2025-2026, Elliot Fontaine <yard-godot@elliotfontaine.anonaddy.com>
# SPDX-FileCopyrightText: 2026-present, YARD contributors (see AUTHORS.md)
#
# SPDX-License-Identifier: MIT
extends "res://addons/yard/editor_only/classes/data_table/cell_types/popup_menu_cell_type.gd"
## Arrays whose elements are picked from a fixed set of options: registry string
## IDs (Registry.PROPERTY_HINT_CUSTOM) or int enum values. Elements are drawn as
## colored tags. The popup adds elements: one per pick when the array allows
## duplicates, check items otherwise (unchecking one also removes it).

const RegistryIO := Namespace.RegistryIO
const RegistryEntryCellType := Namespace.RegistryEntryCellType


static func matches(column: ColumnConfig) -> bool:
	return _is_registry_array(column) or _is_enum_array(column)


static func draw_cell(
	canvas: CanvasItem,
	rect: Rect2,
	value: Variant,
	column: ColumnConfig,
	style: CellStyle,
) -> void:
	var labels := _get_labels(value, column)
	# The element count tells the array apart from a single value, and shows how
	# many elements a narrow column cuts off.
	var prefix := "[%d]" % labels.size()
	if _is_registry_array(column):
		prefix = "%s %s" % [RegistryEntryCellType.RIGHTWARDS_ARROW, prefix]
	var font := resolve_font(column, style.font)
	var prefix_width := font \
			.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, style.font_size) \
			.x
	var x_margin: int = H_ALIGNMENT_MARGINS.get(HORIZONTAL_ALIGNMENT_LEFT)
	draw_text(
		canvas,
		rect,
		prefix,
		font,
		style.font_size,
		HORIZONTAL_ALIGNMENT_LEFT,
		canvas.get_theme_color(&"readonly_color", &"EditorProperty"),
	)
	draw_tags(canvas, rect.grow_side(SIDE_LEFT, -(prefix_width + x_margin)), labels, column, style)


static func get_tooltip(value: Variant, column: ColumnConfig) -> String:
	return "\n".join(_get_labels(value, column))


static func get_sort_key(value: Variant, column: ColumnConfig) -> Variant:
	return " ".join(_get_labels(value, column))


static func get_filter_key(value: Variant, column: ColumnConfig) -> Variant:
	return " ".join(_get_labels(value, column))


static func create_editor(
	owner: Control,
	rect: Rect2,
	value: Variant,
	column: ColumnConfig,
	on_finished: Callable,
) -> Node:
	var array: Array = value if value is Array else []
	var element_type := array.get_typed_builtin()
	var allow_duplicates := _allows_duplicates(column)
	var options := _get_options(column)

	var popup_menu := PopupMenu.new()
	popup_menu.set_meta(&"array", array)
	for option: Variant in options:
		var element: Variant = option if element_type == TYPE_NIL else type_convert(option, element_type)
		var idx := popup_menu.item_count
		if allow_duplicates:
			popup_menu.add_item(options[option])
		else:
			popup_menu.add_check_item(options[option])
			popup_menu.set_item_checked(idx, element in array)
		popup_menu.set_item_metadata(idx, element)

	if allow_duplicates:
		return popup_single_choice(popup_menu, owner, rect, on_finished)
	return popup_multiple_choice(popup_menu, owner, rect, on_finished)


## Starts from the edited array, so elements the popup doesn't list (IDs no longer
## in the registry, unknown enum values) are kept.
static func read_editor_value(editor: Node, _column: ColumnConfig) -> Variant:
	var popup_menu: PopupMenu = editor
	var original: Array = popup_menu.get_meta(&"array")
	var result := original.duplicate()
	for idx in popup_menu.item_count:
		var element: Variant = popup_menu.get_item_metadata(idx)
		var checked := popup_menu.is_item_checked(idx)
		if not popup_menu.is_item_checkable(idx):
			if checked: # The plain item picked in popup_single_choice().
				result.append(element)
		elif not checked:
			while element in result:
				result.erase(element)
		elif element not in result:
			result.append(element)
	return result


static func _is_registry_array(column: ColumnConfig) -> bool:
	return column.type == TYPE_ARRAY and column.property_hint == Registry.PROPERTY_HINT_CUSTOM


static func _is_enum_array(column: ColumnConfig) -> bool:
	return (
		column.type == TYPE_ARRAY
		and column.property_hint == PROPERTY_HINT_TYPE_STRING
		and column.hint_string.begins_with("%d/%d:" % [TYPE_INT, PROPERTY_HINT_ENUM])
	)


## Enum arrays have no hint for it, so they behave like a set, as flags do.
static func _allows_duplicates(column: ColumnConfig) -> bool:
	if _is_enum_array(column):
		return false
	return RegistryIO.parse_custom_hint(column.hint_string).allow_duplicates


static func _get_enum_map(column: ColumnConfig) -> Dictionary:
	return column.get_cached(
		&"enum_values_map",
		parse_enum_hint_string.bind(column.hint_string.split(":", true, 1)[1]),
	)


## Option value -> label, in popup order.
static func _get_options(column: ColumnConfig) -> Dictionary:
	if _is_enum_array(column):
		return _get_enum_map(column)
	var options := { }
	for string_id in RegistryEntryCellType.get_registry_entries(column.hint_string):
		options[string_id] = str(string_id)
	return options


static func _get_labels(value: Variant, column: ColumnConfig) -> Array[String]:
	var labels: Array[String] = []
	if value is not Array:
		return labels
	var is_enum := _is_enum_array(column)
	var enum_map := _get_enum_map(column) if is_enum else { }
	for element: Variant in value as Array:
		if is_enum:
			labels.append(enum_map.get(element, "?:%s" % element))
		else:
			labels.append(str(element))
	return labels
