import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_staggered_grid_view/src/widgets/staggered_grid.dart';
import 'package:flutter_staggered_grid_view/src/widgets/staggered_grid_tile.dart';

/// Callback for when reordering is complete.
typedef ReorderCallback = void Function(int oldIndex, int newIndex);

/// Callback when feedback is being built.
typedef IndexedFeedBackWidgetBuilder = Widget Function(
  BuildContext context,
  int index,
  Widget child,
);

/// A list whose items the user can interactively reorder by dragging.
///
/// This class is appropriate for views with a small number of
/// children because constructing the [List] requires doing work for every
/// child that could possibly be displayed in the list view instead of just
/// those children that are actually visible.
///
/// All [children] must have a key.
///
class ReorderableStaggeredLayout extends StatefulWidget {
  /// Creates a reorderable list.
  ReorderableStaggeredLayout({
    Key? key,
    this.header,
    required this.children,
    required this.onReorder,
    this.scrollDirection = Axis.vertical,
    this.padding,
    this.crossAxisCount = 3,
    this.longPressToDrag = true,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.feedBackWidgetBuilder,
    this.feedBackBorderRadius,
  }) : super(key: key);

  /// A non-reorderable header widget to show before the list.
  ///
  /// If null, no header will appear before the list.
  final Widget? header;

  /// The widgets to display.
  final List<StaggeredGridTile> children;

  /// The [Axis] along which the list scrolls.
  ///
  /// List [children] can only drag along this [Axis].
  final Axis scrollDirection;

  /// The amount of space by which to inset the [children].
  final EdgeInsets? padding;

  /// Called when a list child is dropped into a new position to shuffle the
  /// underlying list.
  ///
  /// This [ReorderableStaggeredLayout] calls [onReorder] after a list child is dropped
  /// into a new position.
  final ReorderCallback onReorder;

  /// Used when we are building a GridView
  final int crossAxisCount;

  /// Used when we are building a GridView
  final bool longPressToDrag;

  /// Used when we are building a GridView
  final double mainAxisSpacing;

  /// Used when we are building a GridView
  final double crossAxisSpacing;

  /// Feedback widget
  final IndexedFeedBackWidgetBuilder? feedBackWidgetBuilder;

  /// Feedback widget border radius
  final BorderRadius? feedBackBorderRadius;

  @override
  _ReorderableStaggeredLayoutState createState() => _ReorderableStaggeredLayoutState();
}

/// This top-level state manages an Overlay that contains the list and
/// also any Draggables it creates.
///
/// _ReorderableListContent manages the list itself and reorder operations.
///
/// The Overlay doesn't properly keep state by building new overlay entries,
/// and so we cache a single OverlayEntry for use as the list layer.
/// That overlay entry then builds a _ReorderableListContent which may
/// insert Draggables into the Overlay above itself.
class _ReorderableStaggeredLayoutState extends State<ReorderableStaggeredLayout> {
  @override
  Widget build(BuildContext context) {
    return _ReorderableListContent(
      header: widget.header,
      children: widget.children,
      scrollDirection: widget.scrollDirection,
      onReorder: widget.onReorder,
      padding: widget.padding,
      crossAxisCount: widget.crossAxisCount,
      longPressToDrag: widget.longPressToDrag,
      mainAxisSpacing: widget.mainAxisSpacing,
      crossAxisSpacing: widget.crossAxisSpacing,
      feedBackWidgetBuilder: widget.feedBackWidgetBuilder,
      feedBackBorderRadius: widget.feedBackBorderRadius,
    );
  }
}

/// This widget is responsible for the inside of the Overlay in the
/// ReorderableItemsView.
class _ReorderableListContent extends StatefulWidget {
  const _ReorderableListContent({
    required this.header,
    required this.children,
    required this.scrollDirection,
    required this.padding,
    required this.onReorder,
    required this.crossAxisCount,
    required this.longPressToDrag,
    required this.mainAxisSpacing,
    required this.crossAxisSpacing,
    required this.feedBackWidgetBuilder,
    required this.feedBackBorderRadius,
  });

  final Widget? header;
  final List<StaggeredGridTile> children;
  final Axis scrollDirection;
  final EdgeInsets? padding;
  final ReorderCallback onReorder;
  final int crossAxisCount;
  final bool longPressToDrag;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final IndexedFeedBackWidgetBuilder? feedBackWidgetBuilder;
  final BorderRadius? feedBackBorderRadius;

  @override
  _ReorderableListContentState createState() => _ReorderableListContentState();
}

class _ReorderableListContentState extends State<_ReorderableListContent>
    with TickerProviderStateMixin<_ReorderableListContent> {
  /// How long an animation to reorder an element in the list takes.
  static const Duration _reorderAnimationDuration = Duration(milliseconds: 200);

  /// This controls the entrance of the dragging widget into a new place.
  late AnimationController _entranceController;

  /// This controls the 'ghost' of the dragging widget, which is left behind
  /// where the widget used to be.
  late AnimationController _ghostController;

  /// The member of children currently being dragged.
  ///
  /// Null if no drag is underway.
  Widget? _dragging;

  /// The location that the dragging widget occupied before it started to drag.
  int _dragStartIndex = 0;

  /// The index that the dragging widget most recently left.
  /// This is used to show an animation of the widget's position.
  int _ghostIndex = 0;

  /// The index that the dragging widget currently occupies.
  int _currentIndex = 0;

  /// The widget to move the dragging widget too after the current index.
  int _nextIndex = 0;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(vsync: this, duration: _reorderAnimationDuration);
    _ghostController = AnimationController(vsync: this, duration: _reorderAnimationDuration);
    _entranceController.addStatusListener(_onEntranceStatusChanged);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ghostController.dispose();
    super.dispose();
  }

  /// Animates the droppable space from _currentIndex to _nextIndex.
  void _requestAnimationToNextIndex() {
    if (_entranceController.isCompleted) {
      _ghostIndex = _currentIndex;
      if (_nextIndex == _currentIndex) {
        return;
      }
      _currentIndex = _nextIndex;
      _ghostController.reverse(from: 1.0);
      _entranceController.forward(from: 0.0);
    }
  }

  /// Requests animation to the latest next index if it changes during an animation.
  void _onEntranceStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(_requestAnimationToNextIndex);
    }
  }

  /// Wraps children in Row or Column, so that the children flow in
  /// the widget's scrollDirection.
  Widget _buildContainerForScrollDirection({required List<Widget> children}) {
    if (widget.header != null) {
      if (children[1] is StaggeredGridTile)
        return StaggeredGrid.count(
          crossAxisCount: widget.crossAxisCount,
          children: children,
          mainAxisSpacing: widget.mainAxisSpacing,
          crossAxisSpacing: widget.crossAxisSpacing,
        );
    } else {
      if (children.first is StaggeredGridTile)
        return StaggeredGrid.count(
          crossAxisCount: widget.crossAxisCount,
          children: children,
          mainAxisSpacing: widget.mainAxisSpacing,
          crossAxisSpacing: widget.crossAxisSpacing,
        );
    }

    switch (widget.scrollDirection) {
      case Axis.horizontal:
        return Row(children: children);
      case Axis.vertical:
      default:
        return Column(children: children);
    }
  }

  /// Wraps one of the widget's children in a DragTarget and Draggable.
  /// Handles up the logic for dragging and reordering items in the list.
  StaggeredGridTile _wrap(
    StaggeredGridTile toWrap,
    int index,
    BoxConstraints constraints,
  ) {
    if (toWrap.disableDrag) {
      return toWrap;
    }
    final GlobalObjectKey keyIndexGlobalKey = GlobalObjectKey(toWrap);
    // We pass the toWrapWithGlobalKey into the Draggable so that when a list
    // item gets dragged, the accessibility framework can preserve the selected
    // state of the dragging item.

    // Starts dragging toWrap.
    void onDragStarted() {
      setState(() {
        _dragging = toWrap;
        _dragStartIndex = index;
        _ghostIndex = index;
        _currentIndex = index;
        _entranceController.value = 1.0;
      });
    }

    /// Places the value from startIndex one space before the element at endIndex.
    void reorder(int startIndex, int endIndex) {
      setState(() {
        if (startIndex != endIndex && endIndex < widget.children.length)
          widget.onReorder(startIndex, endIndex);
        _ghostController.reverse(from: 0.1);
        _entranceController.reverse(from: 0.1);
        _dragging = null;
      });
    }

    /// Drops toWrap into the last position it was hovering over.
    void onDragEnded() {
      reorder(_dragStartIndex, _currentIndex);
    }

    Widget wrapWithSemantics() {
      // First, determine which semantics actions apply.
      final Map<CustomSemanticsAction, VoidCallback> semanticsActions =
          <CustomSemanticsAction, VoidCallback>{};

      // Create the appropriate semantics actions.
      void moveToStart() => reorder(index, 0);
      void moveToEnd() => reorder(index, widget.children.length);
      void moveBefore() => reorder(index, index - 1);
      // To move after, we go to index+2 because we are moving it to the space
      // before index+2, which is after the space at index+1.
      void moveAfter() => reorder(index, index + 2);

      final MaterialLocalizations localizations = MaterialLocalizations.of(context);

      // If the item can move to before its current position in the list.
      if (index > 0) {
        semanticsActions[CustomSemanticsAction(
          label: localizations.reorderItemToStart,
        )] = moveToStart;
        String reorderItemBefore = localizations.reorderItemUp;
        if (widget.scrollDirection == Axis.horizontal) {
          reorderItemBefore = Directionality.of(context) == TextDirection.ltr
              ? localizations.reorderItemLeft
              : localizations.reorderItemRight;
        }
        semanticsActions[CustomSemanticsAction(label: reorderItemBefore)] = moveBefore;
      }

      // If the item can move to after its current position in the list.
      if (index < widget.children.length - 1) {
        String reorderItemAfter = localizations.reorderItemDown;
        if (widget.scrollDirection == Axis.horizontal) {
          reorderItemAfter = Directionality.of(context) == TextDirection.ltr
              ? localizations.reorderItemRight
              : localizations.reorderItemLeft;
        }
        semanticsActions[CustomSemanticsAction(label: reorderItemAfter)] = moveAfter;
        semanticsActions[CustomSemanticsAction(label: localizations.reorderItemToEnd)] = moveToEnd;
      }

      // We pass toWrap with a GlobalKey into the Draggable so that when a list
      // item gets dragged, the accessibility framework can preserve the selected
      // state of the dragging item.
      //
      // We also apply the relevant custom accessibility actions for moving the item
      // up, down, to the start, and to the end of the list.
      return KeyedSubtree(
        key: keyIndexGlobalKey,
        child: MergeSemantics(
          child: Semantics(
            customSemanticsActions: semanticsActions,
            child: toWrap.child,
          ),
        ),
      );
    }

    Widget buildDragTarget(
      BuildContext context,
      List<Widget?> acceptedCandidates,
      List<dynamic> rejectedCandidates,
    ) {
      final Widget toWrapWithSemantics = wrapWithSemantics();

      double mainAxisExtent = 0.0;
      double crossAxisExtent = 0.0;

      BoxConstraints newConstraints = constraints;

      if (_dragging == null && index < widget.children.length) {
        final StaggeredGridTile tile = widget.children[index];

        final double usableCrossAxisExtent = constraints.biggest.width;
        final double cellExtent = usableCrossAxisExtent / widget.crossAxisCount;
        final num mainAxisCellCount = tile.mainAxisCellCount ?? 1.0;

        mainAxisExtent =
            tile.mainAxisExtent ?? (mainAxisCellCount * cellExtent) + (mainAxisCellCount - 1);

        crossAxisExtent = cellExtent * tile.crossAxisCellCount;

        newConstraints = constraints.copyWith(
          minWidth: crossAxisExtent,
          maxWidth: crossAxisExtent,
          minHeight: mainAxisExtent,
          maxHeight: mainAxisExtent,
        );
      } else {
        newConstraints = constraints.copyWith(
          minWidth: 0.0,
          maxWidth: constraints.maxWidth,
          minHeight: 0.0,
          maxHeight: constraints.maxHeight,
        );
      }

      // We build the draggable inside of a layout builder so that we can
      // constrain the size of the feedback dragging widget.
      Widget child = widget.longPressToDrag
          ? LongPressDraggable<Widget>(
              maxSimultaneousDrags: 1,
              axis: null,
              data: toWrap,
              ignoringFeedbackSemantics: false,
              feedback: widget.feedBackWidgetBuilder != null
                  ? widget.feedBackWidgetBuilder!(
                      context,
                      index,
                      toWrapWithSemantics,
                    )
                  : ClipRRect(
                      borderRadius: widget.feedBackBorderRadius ?? BorderRadius.zero,
                      child: Container(
                        alignment: Alignment.topLeft,
                        // These constraints will limit the cross axis of the drawn widget.
                        constraints: newConstraints,
                        color: Colors.transparent,
                        child: Material(
                          borderRadius: widget.feedBackBorderRadius ?? BorderRadius.zero,
                          elevation: 6.0,
                          child: toWrapWithSemantics,
                        ),
                      ),
                    ),

              child: _dragging == toWrap ? const SizedBox() : toWrapWithSemantics,
              childWhenDragging: const SizedBox(),
              onDragStarted: onDragStarted,
              dragAnchorStrategy: childDragAnchorStrategy,
              // When the drag ends inside a DragTarget widget, the drag
              // succeeds, and we reorder the widget into position appropriately.
              onDragCompleted: onDragEnded,
              // When the drag does not end inside a DragTarget widget, the
              // drag fails, but we still reorder the widget to the last position it
              // had been dragged to.
              onDraggableCanceled: (Velocity velocity, Offset offset) {
                onDragEnded();
              },
            )
          : Draggable<Widget>(
              maxSimultaneousDrags: 1,
              axis: null,
              data: toWrap,
              ignoringFeedbackSemantics: false,
              feedback: widget.feedBackWidgetBuilder != null
                  ? widget.feedBackWidgetBuilder!(
                      context,
                      index,
                      toWrapWithSemantics,
                    )
                  : Container(
                      alignment: Alignment.topLeft,
                      // These constraints will limit the cross axis of the drawn widget.
                      constraints: newConstraints,
                      child: Material(
                        elevation: 6.0,
                        color: Colors.transparent,
                        child: toWrapWithSemantics,
                      ),
                    ),
              child: _dragging == toWrap ? const SizedBox() : toWrapWithSemantics,
              childWhenDragging: const SizedBox(),
              onDragStarted: onDragStarted,
              dragAnchorStrategy: childDragAnchorStrategy,
              // When the drag ends inside a DragTarget widget, the drag
              // succeeds, and we reorder the widget into position appropriately.
              onDragCompleted: onDragEnded,
              // When the drag does not end inside a DragTarget widget, the
              // drag fails, but we still reorder the widget to the last position it
              // had been dragged to.
              onDraggableCanceled: (Velocity velocity, Offset offset) {
                onDragEnded();
              },
            );

      // The target for dropping at the end of the list doesn't need to be
      // draggable.
      if (index >= widget.children.length) {
        child = toWrap;
      }

      if (_dragging != null) {
        if (index == _ghostIndex) {
          return const SizedBox.shrink();
        } else if (index < _ghostIndex && _dragStartIndex < _ghostIndex) {
          return widget.children[index + 1];
        } else if (index > _ghostIndex &&
            index <= _dragStartIndex &&
            _dragStartIndex > _ghostIndex) {
          return widget.children[index - 1];
        }
      }
      return child;
    }

    Widget target = Builder(
      builder: (BuildContext context) {
        return DragTarget<Widget>(
          builder: buildDragTarget,
          onWillAcceptWithDetails: (DragTargetDetails<Widget> toAccept) {
            setState(() {
              _nextIndex = index;
              _requestAnimationToNextIndex();
            });
            // If the target is not the original starting point, then we will accept the drop.
            return _dragging == toAccept.data && toAccept.data != toWrap;
          },
          onAcceptWithDetails: (DragTargetDetails<Widget> accepted) {},
          onLeave: (Object? leaving) {},
        );
      },
    );

    // We wrap the drag target in a Builder so that we can scroll to its specific context.

    if (toWrap.mainAxisCellCount != null) {
      return StaggeredGridTile.count(
        crossAxisCellCount: toWrap.crossAxisCellCount,
        mainAxisCellCount: toWrap.mainAxisCellCount!,
        child: target,
      );
    } else if (toWrap.mainAxisExtent != null) {
      return StaggeredGridTile.extent(
        crossAxisCellCount: toWrap.crossAxisCellCount,
        mainAxisExtent: toWrap.mainAxisExtent!,
        child: target,
      );
    } else {
      return StaggeredGridTile.fit(
        crossAxisCellCount: toWrap.crossAxisCellCount,
        child: target,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    // We use the layout builder to constrain the cross-axis size of dragging child widgets.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Padding(
          padding: widget.padding ?? EdgeInsets.zero,
          child: _buildContainerForScrollDirection(
            children: <Widget>[
              if (widget.header != null) widget.header!,
              for (int i = 0; i < widget.children.length; i += 1)
                _wrap(widget.children[i], i, constraints),
            ],
          ),
        );
      },
    );
  }
}
