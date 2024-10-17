import 'package:flutter/material.dart';

/// Entrypoint of the application.
void main() {
  runApp(const MyApp());
}

/// [Widget] building the [MaterialApp].
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Dock(
            items: const [
              Icons.person,
              Icons.message,
              Icons.call,
              Icons.camera,
              Icons.photo,
            ],
            builder: (e) {
              return Container(
                height: 48,
                width: 48,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.primaries[e.hashCode % Colors.primaries.length],
                ),
                child: Center(child: Icon(e, color: Colors.white)),
              );
            },
            targetBuilder: () {
              return Container(
                height: 48,
                width: 48,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.transparent,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Dock of the reorderable [items].
class Dock<T> extends StatefulWidget {
  const Dock({
    super.key,
    this.items = const [],
    required this.builder,
    required this.targetBuilder,
  });

  /// Initial [T] items to put in this [Dock].
  final List<T> items;

  /// Builder building the provided [T] item.
  final Widget Function(T) builder;

  final Widget Function() targetBuilder;

  @override
  State<Dock<T>> createState() => _DockState<T>();
}

/// State of the [Dock] used to manipulate the [_items].
class _DockState<T> extends State<Dock<T>> {
  /// [T] items being manipulated.
  late List<T> _items = widget.items.toList();

  /// Keys for tracking each items
  List<GlobalKey> _itemKeys = [];

  /// Animated positions of each icons.
  List<Offset> _itemAnimatedOffsets = [];

  /// Target positions for drag-and-drop.
  List<Offset> _itemDragTargetOffsets = [];

  int? _draggingIndex; // Index of the item being dragged.
  bool _hasMovingAnimation = false; // Animation state flag.
  bool _showSelectedItemDraggedTarget = false; // Flag for showing the dragged item slot.
  Offset _selectedItemDraggedTargetOffset = Offset(0, 0); // Position of the dragged item.
  bool _hasCurrentProcess = false; // Flag for ongoing drag-drop process.

  static const int animationDuration = 400;

  @override
  void initState() {
    initItems();
    checkListRendered();
    super.initState();
  }

  /// Initialize item keys and offsets.
  void initItems() {
    _itemKeys.clear();
    _itemAnimatedOffsets.clear();
    for (var _ in _items) {
      const offset = Offset(0, 0);
      final key = GlobalKey();
      _itemKeys.add(key);
      _itemAnimatedOffsets.add(offset);
    }
  }

  /// Capture the actual rendered positions of the items after the first frame.
  void checkListRendered() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      var ctr = 0;
      for (final key in _itemKeys) {
        final offset = getOffsetByKey(key);
        setState(() {
          _itemAnimatedOffsets[ctr] = offset;
          _itemDragTargetOffsets.add(offset);
        });
        ctr++;
      }
    });
  }

  /// Get the global offset (position) of a widget by its key.
  Offset getOffsetByKey(GlobalKey key) {
    final box = key.currentContext!.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    return offset;
  }

  /// Move all items back to their original positions.
  void moveAnimatedItemsToItsOriginalPosition({bool hasAnimation = true}) {
    setState(() {
      _hasMovingAnimation = hasAnimation;
      var ctr = 0;
      for (final _ in _items) {
        final offset = _itemDragTargetOffsets[ctr];
        _itemAnimatedOffsets[ctr] = offset;
        ctr++;
      }
    });
  }

  /// Helper function to reorder list items based on drag-and-drop.
  List<int> moveElement(int fromIndex, int toIndex) {
    var ctr = 0;
    List<int> list = [];
    for (var _ in _items) {
      list.add(ctr);
      ctr++;
    }
    if (fromIndex < 0 || fromIndex >= list.length || toIndex < 0 || toIndex >= list.length) {
      return list;
    }
    List<int> newList = List<int>.from(list);
    int element = newList.removeAt(fromIndex);
    newList.insert(toIndex, element);
    return newList;
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        //This is use to know if the icon is dragging somewhere outside the target area.
        //When you drag an icon, there would be an extra space. To resolve that, we will adjust the icon position to align them to center.
        if (_draggingIndex != null) {
          var ctr = 0;
          for (final offsets in _itemDragTargetOffsets) {
            if (_draggingIndex != ctr) {
              double dx = 0;
              if (_draggingIndex! > ctr) {
                dx = offsets.dx + 31;
              } else {
                dx = offsets.dx - 31;
              }
              setState(() {
                _hasMovingAnimation = true;
                _itemAnimatedOffsets[ctr] = Offset(dx, offsets.dy);
              });
            }
            ctr++;
          }
        }
        return false;
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(
          alignment: Alignment.center,
          children: [
            /// The target slots (drag-and-drop areas).
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black12,
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  _items.length,
                  (index) {
                    final itemIndex = index;
                    final itemKey = _itemKeys[itemIndex];
                    final itemWidget = widget.targetBuilder();
                    final itemIconWidget = widget.builder(_items[itemIndex]);
                    return Draggable<int>(
                      data: itemIndex,
                      onDragStarted: () {
                        setState(() {
                          _draggingIndex = itemIndex;
                          _showSelectedItemDraggedTarget = true;
                          final offset = _itemDragTargetOffsets[itemIndex];
                          _selectedItemDraggedTargetOffset = offset;
                        });
                      },
                      onDraggableCanceled: (velocity, offset) async {
                        // Animation effect of the icon when it drops somewhere else.
                        setState(() {
                          _hasCurrentProcess = true;
                          _hasMovingAnimation = false;
                          _showSelectedItemDraggedTarget = false;
                          _itemAnimatedOffsets[itemIndex] = offset;
                          _draggingIndex = null;
                        });
                        await Future.delayed(const Duration(milliseconds: 100));
                        moveAnimatedItemsToItsOriginalPosition();
                        await Future.delayed(const Duration(milliseconds: animationDuration));
                        setState(() {
                          _hasCurrentProcess = false;
                        });
                      },
                      feedback: itemIconWidget,
                      childWhenDragging: itemWidget,
                      child: DragTarget<int>(
                        onAcceptWithDetails: (details) async {
                          final offset = details.offset;
                          final fromIndex = details.data;
                          final toIndex = index;

                          //Animation effect of the icon when drop to the desired target area.
                          setState(() {
                            _hasCurrentProcess = true;
                            _draggingIndex = null;
                            _hasMovingAnimation = false;
                            _showSelectedItemDraggedTarget = false;
                            _itemAnimatedOffsets[fromIndex] = offset;
                          });
                          await Future.delayed(const Duration(milliseconds: 100));
                          setState(() {
                            _hasMovingAnimation = true;
                            final targetOffset = _itemDragTargetOffsets[toIndex];
                            _itemAnimatedOffsets[fromIndex] = targetOffset;
                          });
                          await Future.delayed(const Duration(milliseconds: animationDuration));

                          //Determine the sorted list
                          final newList = moveElement(fromIndex, toIndex);
                          final sortedItems = newList.map((index) => _items[index]).toList();
                          setState(() {
                            _items.clear();
                            _items.addAll(sortedItems);
                          });

                          moveAnimatedItemsToItsOriginalPosition(hasAnimation: false);
                          setState(() {
                            _hasCurrentProcess = false;
                          });
                        },
                        onWillAcceptWithDetails: (details) {
                          // Animation effect that moves the other items while the icon is being dragged.
                          final fromIndex = details.data;
                          final toIndex = index;
                          final newList = moveElement(fromIndex, toIndex);
                          var ctr = 0;
                          for (final itemI in newList) {
                            if (itemI != fromIndex) {
                              final targetOffset = _itemDragTargetOffsets[ctr];
                              setState(() {
                                _hasMovingAnimation = true;
                                _itemAnimatedOffsets[itemI] = targetOffset;
                              });
                            }
                            ctr++;
                          }
                          return true;
                        },
                        builder: (context, candidateData, rejectedData) {
                          return Container(key: itemKey, child: itemWidget);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

            /// Render items / icons in their animated positions.
            IgnorePointer(
              ignoring: !_hasCurrentProcess,
              child: Stack(
                fit: StackFit.passthrough,
                children: List.generate(
                  _items.length,
                  (index) {
                    int itemIndex = index;
                    final itemWidget = widget.builder(_items[itemIndex]);
                    final top = _itemAnimatedOffsets[itemIndex].dy;
                    final left = _itemAnimatedOffsets[itemIndex].dx;
                    return AnimatedPositioned(
                      top: top,
                      left: left,
                      curve: Curves.bounceOut,
                      duration: Duration(milliseconds: _hasMovingAnimation ? animationDuration : 0),
                      child: Opacity(opacity: itemIndex == _draggingIndex ? 0 : 1, child: itemWidget),
                    );
                  },
                ),
              ),
            ),

            /// Selected item dragged target visual feedback.
            if (_showSelectedItemDraggedTarget && _draggingIndex != null)
              AnimatedPositioned(
                top: _selectedItemDraggedTargetOffset.dy,
                left: _selectedItemDraggedTargetOffset.dx,
                duration: const Duration(milliseconds: 0),
                child: DragTarget<int>(
                  onAcceptWithDetails: (details) async {
                    setState(() {
                      _hasCurrentProcess = true;
                    });
                    final offset = details.offset;
                    final fromIndex = details.data;
                    final toIndex = _draggingIndex;
                    if (fromIndex == toIndex) {
                      // Add an animation when the user drop the icon to its original position.
                      setState(() {
                        _draggingIndex = null;
                        _hasMovingAnimation = false;
                        _showSelectedItemDraggedTarget = false;
                        _itemAnimatedOffsets[fromIndex] = offset;
                      });
                      await Future.delayed(const Duration(milliseconds: 100));
                      setState(() {
                        _hasMovingAnimation = true;
                        final targetOffset = _itemDragTargetOffsets[fromIndex];
                        _itemAnimatedOffsets[fromIndex] = targetOffset;
                      });
                    }
                    setState(() {
                      _hasCurrentProcess = false;
                    });
                  },
                  onWillAcceptWithDetails: (_) {
                    // When icon is about to drop to its original position, all other icons should go back to their original position.
                    moveAnimatedItemsToItsOriginalPosition();
                    return true;
                  },
                  builder: (context, candidateData, rejectedData) {
                    return widget.targetBuilder();
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
