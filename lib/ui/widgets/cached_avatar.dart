import 'dart:typed_data';

import 'package:flutter/material.dart';

/// A CircleAvatar that caches the MemoryImage to prevent blinking on rebuilds.
/// 
/// The image is only recreated when the imageBytes actually change (by comparing length
/// and first/last bytes as a fast heuristic).
class CachedAvatar extends StatefulWidget {
  const CachedAvatar({
    super.key,
    this.imageBytes,
    this.radius = 24,
    this.backgroundColor,
    this.fallbackIcon = Icons.person,
    this.fallbackIconSize,
  });

  /// The raw image bytes (e.g., from user.profileImageBytes).
  final List<int>? imageBytes;
  
  /// Radius of the avatar.
  final double radius;
  
  /// Background color when no image is present.
  final Color? backgroundColor;
  
  /// Icon to show when no image is available.
  final IconData fallbackIcon;
  
  /// Size of the fallback icon. Defaults to radius.
  final double? fallbackIconSize;

  @override
  State<CachedAvatar> createState() => _CachedAvatarState();
}

class _CachedAvatarState extends State<CachedAvatar> {
  MemoryImage? _cachedImage;
  int? _cachedLength;
  int? _cachedFirstByte;
  int? _cachedLastByte;

  @override
  void initState() {
    super.initState();
    _updateCachedImage();
  }

  @override
  void didUpdateWidget(CachedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only rebuild image if the bytes actually changed
    if (_hasImageChanged()) {
      _updateCachedImage();
    }
  }

  bool _hasImageChanged() {
    final bytes = widget.imageBytes;
    if (bytes == null && _cachedLength == null) return false;
    if (bytes == null || _cachedLength == null) return true;
    if (bytes.length != _cachedLength) return true;
    if (bytes.isEmpty) return _cachedLength != 0;
    if (bytes.first != _cachedFirstByte) return true;
    if (bytes.last != _cachedLastByte) return true;
    return false;
  }

  void _updateCachedImage() {
    final bytes = widget.imageBytes;
    if (bytes != null && bytes.isNotEmpty) {
      _cachedImage = MemoryImage(Uint8List.fromList(bytes));
      _cachedLength = bytes.length;
      _cachedFirstByte = bytes.first;
      _cachedLastByte = bytes.last;
    } else {
      _cachedImage = null;
      _cachedLength = null;
      _cachedFirstByte = null;
      _cachedLastByte = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor ?? theme.colorScheme.primaryContainer,
      backgroundImage: _cachedImage,
      child: _cachedImage == null
          ? Icon(
              widget.fallbackIcon,
              size: widget.fallbackIconSize ?? widget.radius,
              color: theme.colorScheme.onPrimaryContainer,
            )
          : null,
    );
  }
}

/// A rectangular cached image widget for non-avatar use cases.
class CachedProfileImage extends StatefulWidget {
  const CachedProfileImage({
    super.key,
    this.imageBytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  final List<int>? imageBytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  @override
  State<CachedProfileImage> createState() => _CachedProfileImageState();
}

class _CachedProfileImageState extends State<CachedProfileImage> {
  MemoryImage? _cachedImage;
  int? _cachedLength;
  int? _cachedFirstByte;
  int? _cachedLastByte;

  @override
  void initState() {
    super.initState();
    _updateCachedImage();
  }

  @override
  void didUpdateWidget(CachedProfileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hasImageChanged()) {
      _updateCachedImage();
    }
  }

  bool _hasImageChanged() {
    final bytes = widget.imageBytes;
    if (bytes == null && _cachedLength == null) return false;
    if (bytes == null || _cachedLength == null) return true;
    if (bytes.length != _cachedLength) return true;
    if (bytes.isEmpty) return _cachedLength != 0;
    if (bytes.first != _cachedFirstByte) return true;
    if (bytes.last != _cachedLastByte) return true;
    return false;
  }

  void _updateCachedImage() {
    final bytes = widget.imageBytes;
    if (bytes != null && bytes.isNotEmpty) {
      _cachedImage = MemoryImage(Uint8List.fromList(bytes));
      _cachedLength = bytes.length;
      _cachedFirstByte = bytes.first;
      _cachedLastByte = bytes.last;
    } else {
      _cachedImage = null;
      _cachedLength = null;
      _cachedFirstByte = null;
      _cachedLastByte = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    
    if (_cachedImage != null) {
      child = Image(
        image: _cachedImage!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true, // Prevents flicker during image updates
      );
    } else {
      child = widget.placeholder ?? 
          Container(
            width: widget.width,
            height: widget.height,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.person,
              size: (widget.width ?? 48) / 2,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: child,
      );
    }

    return child;
  }
}
