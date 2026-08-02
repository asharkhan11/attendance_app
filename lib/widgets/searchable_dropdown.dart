import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A dropdown selector replaced with a search field.
/// - Shows all available values when clicked/focused without typing.
/// - Shows only matching values as the user types in the search field.
/// - Supports mouse click selection, hover highlight, dynamic sizing, and keyboard navigation (Arrow Up/Down, Enter, Escape).
class SearchableDropdown<T> extends StatefulWidget {
  final T? value;
  final List<T> items;
  final String Function(T item) itemAsString;
  final Widget Function(BuildContext context, T item, bool isSelected)? itemBuilder;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final String? hintText;
  final InputDecoration? decoration;
  final bool isDense;
  final bool enabled;
  final bool showSearchIcon;

  const SearchableDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.itemAsString,
    this.itemBuilder,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.decoration,
    this.isDense = false,
    this.enabled = true,
    this.showSearchIcon = false,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final Object _tapRegionGroupId = Object();

  OverlayEntry? _overlayEntry;
  bool _isUserTyping = false;
  String _typedQuery = '';
  T? _selectedVal;
  int _highlightedIndex = 0;
  List<T> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _selectedVal = widget.value;
    _controller = TextEditingController(text: _getDisplayText(_selectedVal));
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value || !_isEqual(widget.value, _selectedVal)) {
      _selectedVal = widget.value;
      if (!_focusNode.hasFocus) {
        _controller.text = _getDisplayText(_selectedVal);
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _removeOverlay();
    super.dispose();
  }

  String _getDisplayText(T? val) {
    if (val == null) return '';
    return widget.itemAsString(val);
  }

  bool _isEqual(T? a, T? b) {
    if (a == b) return true;
    if (a == null || b == null) return false;
    return widget.itemAsString(a) == widget.itemAsString(b);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _isUserTyping = false;
      _typedQuery = '';
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
      _updateFilteredItems();
      _showOverlay();
    } else {
      _removeOverlay();
      _controller.text = _getDisplayText(_selectedVal);
    }
  }

  void _updateFilteredItems() {
    final query = _isUserTyping ? _typedQuery.trim().toLowerCase() : '';
    _filteredItems = widget.items.where((item) {
      if (query.isEmpty) return true;
      return widget.itemAsString(item).toLowerCase().contains(query);
    }).toList();

    int initialIndex = _filteredItems.indexWhere((item) => _isEqual(item, _selectedVal));
    if (initialIndex < 0) initialIndex = 0;
    _highlightedIndex = initialIndex.clamp(0, _filteredItems.isEmpty ? 0 : _filteredItems.length - 1);
  }

  void _moveHighlight(int delta) {
    if (_filteredItems.isEmpty) return;
    setState(() {
      _highlightedIndex = (_highlightedIndex + delta).clamp(0, _filteredItems.length - 1);
    });
    _scrollToHighlightedIndex();
    _updateOverlay();
  }

  void _scrollToHighlightedIndex() {
    if (!_scrollController.hasClients) return;
    const double itemHeight = 40.0;
    final double targetOffset = _highlightedIndex * itemHeight;
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double currentScroll = _scrollController.offset;
    final double viewportHeight = _scrollController.position.viewportDimension;

    if (targetOffset < currentScroll) {
      _scrollController.jumpTo(targetOffset.clamp(0.0, maxScroll));
    } else if (targetOffset + itemHeight > currentScroll + viewportHeight) {
      _scrollController.jumpTo((targetOffset + itemHeight - viewportHeight).clamp(0.0, maxScroll));
    }
  }

  void _selectItem(T item) {
    _selectedVal = item;
    _controller.text = _getDisplayText(item);
    widget.onChanged?.call(item);
    _removeOverlay();
    _focusNode.unfocus();
  }

  void _showOverlay() {
    _removeOverlay();

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    final spaceBelow = screenSize.height - (offset.dy + size.height);
    final spaceAbove = offset.dy;
    final showAbove = spaceBelow < 200 && spaceAbove > spaceBelow;
    final double maxAvailableHeight = showAbove
        ? (spaceAbove - 16).clamp(80.0, 220.0)
        : (spaceBelow - 16).clamp(80.0, 220.0);

    // Calculate exact content height so card fits items cleanly without excess whitespace
    final double contentHeight = _filteredItems.isEmpty
        ? 48.0
        : (_filteredItems.length * 40.0).clamp(40.0, maxAvailableHeight);

    final overlayOffset = showAbove
        ? Offset(0, -contentHeight - 4)
        : Offset(0, size.height + 4);

    final double popupWidth = size.width.clamp(140.0, 240.0);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: overlayOffset,
          child: Align(
            alignment: Alignment.topLeft,
            child: TapRegion(
              groupId: _tapRegionGroupId,
              onTapOutside: (_) => _focusNode.unfocus(),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).cardColor,
                child: SizedBox(
                  width: popupWidth,
                  height: contentHeight,
                  child: StatefulBuilder(
                    builder: (context, setOverlayState) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: _filteredItems.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text('No matching results', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.zero,
                                itemCount: _filteredItems.length,
                                itemBuilder: (context, index) {
                                  final item = _filteredItems[index];
                                  final isSelected = _isEqual(item, _selectedVal);
                                  final isHighlighted = index == _highlightedIndex;

                                  return Listener(
                                    onPointerDown: (_) => _selectItem(item),
                                    child: MouseRegion(
                                      onEnter: (_) {
                                        setOverlayState(() {
                                          _highlightedIndex = index;
                                        });
                                      },
                                      child: Container(
                                        height: 40.0,
                                        color: isHighlighted
                                            ? Theme.of(context).primaryColor.withValues(alpha: 0.15)
                                            : (isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.05) : null),
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        alignment: Alignment.centerLeft,
                                        child: widget.itemBuilder != null
                                            ? widget.itemBuilder!(context, item, isSelected)
                                            : Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      widget.itemAsString(item),
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: isSelected || isHighlighted ? FontWeight.bold : FontWeight.normal,
                                                        color: isSelected ? Theme.of(context).primaryColor : null,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isSelected)
                                                    Icon(Icons.check, size: 16, color: Theme.of(context).primaryColor),
                                                ],
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDecoration = (widget.decoration ??
            InputDecoration(
              hintText: widget.hintText ?? widget.labelText ?? 'Select Class',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ))
        .copyWith(
      prefixIcon: widget.showSearchIcon ? const Icon(Icons.search, size: 18) : null,
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_controller.text.isNotEmpty && _focusNode.hasFocus)
            IconButton(
              icon: const Icon(Icons.clear, size: 16),
              onPressed: () {
                _controller.clear();
                setState(() {
                  _isUserTyping = true;
                  _typedQuery = '';
                  _updateFilteredItems();
                });
                _updateOverlay();
              },
            ),
          const Icon(Icons.arrow_drop_down, size: 20),
          const SizedBox(width: 4),
        ],
      ),
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: TapRegion(
        groupId: _tapRegionGroupId,
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                if (_overlayEntry == null) {
                  _focusNode.requestFocus();
                } else {
                  _moveHighlight(1);
                }
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                if (_overlayEntry != null) {
                  _moveHighlight(-1);
                }
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                if (_overlayEntry != null && _filteredItems.isNotEmpty) {
                  final index = _highlightedIndex.clamp(0, _filteredItems.length - 1);
                  _selectItem(_filteredItems[index]);
                  return KeyEventResult.handled;
                }
              } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                if (_overlayEntry != null) {
                  _focusNode.unfocus();
                  return KeyEventResult.handled;
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            onChanged: (text) {
              setState(() {
                _isUserTyping = true;
                _typedQuery = text;
                _updateFilteredItems();
              });
              _updateOverlay();
            },
            onTap: () {
              if (!_focusNode.hasFocus) {
                _focusNode.requestFocus();
              } else if (_overlayEntry == null) {
                _showOverlay();
              }
            },
            decoration: effectiveDecoration,
          ),
        ),
      ),
    );
  }
}
