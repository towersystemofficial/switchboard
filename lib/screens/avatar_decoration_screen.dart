import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../models/member.dart';
import '../widgets/avatar_decorations.dart';
import '../widgets/avatar_frame_shapes.dart';
import '../widgets/member_avatar.dart';

class AvatarEditResult {
  final File? pickedAvatar;
  final String glowEffectId;
  final String frameShapeId;
  const AvatarEditResult({
    this.pickedAvatar,
    required this.glowEffectId,
    required this.frameShapeId,
  });
}

/// Full-screen avatar editor: change/crop the photo (top), preview the
/// final combined result live, pick a glow effect from a dropdown, and
/// pick a frame shape from a flat grid -- glow effect and frame shape
/// are fully independent.
class AvatarDecorationScreen extends StatefulWidget {
  final Member previewMember; // caller sets colorHex/name already
  final String? initialAvatarPath;
  final File? initialPickedAvatar;
  final String initialGlowEffectId;
  final String initialFrameShapeId;
  final bool decorationsEnabled;

  /// If editing this member from within a Group view, the group's own
  /// color -- shown as the same top-to-bottom gradient here as it would
  /// render in the actual group drilldown.
  final Color? gradientRingTopColor;

  const AvatarDecorationScreen({
    super.key,
    required this.previewMember,
    required this.initialAvatarPath,
    required this.initialPickedAvatar,
    required this.initialGlowEffectId,
    required this.initialFrameShapeId,
    required this.decorationsEnabled,
    this.gradientRingTopColor,
  });

  @override
  State<AvatarDecorationScreen> createState() => _AvatarDecorationScreenState();
}

class _AvatarDecorationScreenState extends State<AvatarDecorationScreen> {
  File? _pickedAvatar;
  late String _glowEffectId;
  late String _frameShapeId;

  @override
  void initState() {
    super.initState();
    _pickedAvatar = widget.initialPickedAvatar;
    _glowEffectId = widget.initialGlowEffectId;
    _frameShapeId = widget.initialFrameShapeId;
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 90);
    if (file == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Avatar',
          cropStyle: CropStyle.circle,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Avatar',
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
        ),
      ],
    );
    if (cropped != null) {
      setState(() => _pickedAvatar = File(cropped.path));
    }
  }

  void _done() {
    Navigator.of(context).pop(AvatarEditResult(
      pickedAvatar: _pickedAvatar,
      glowEffectId: _glowEffectId,
      frameShapeId: _frameShapeId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final previewPath = _pickedAvatar?.path ?? widget.initialAvatarPath;
    final previewMember = widget.previewMember.copyWith(
      glowEffectId: _glowEffectId,
      frameShapeId: _frameShapeId,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Avatar'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _done),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  MemberAvatar(
                    member: previewMember,
                    radius: 64,
                    avatarFullPath: previewPath,
                    showColorRing: true,
                    gradientRingTopColor: widget.gradientRingTopColor,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.edit, size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Change photo'),
            ),
          ),

          if (widget.decorationsEnabled) ...[
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _glowEffectId,
              decoration: const InputDecoration(labelText: 'Glow effect', border: OutlineInputBorder()),
              items: [
                for (final entry in kGlowEffectCatalog.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value.label)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _glowEffectId = v);
              },
            ),
            const SizedBox(height: 24),
            const Text('Frame shape', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 4,
              childAspectRatio: 0.78,
              children: [
                for (final entry in kFrameShapeCatalog.entries)
                  GestureDetector(
                    onTap: () => setState(() => _frameShapeId = entry.key),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: _frameShapeId == entry.key
                                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                : null,
                          ),
                          child: MemberAvatar(
                            member: widget.previewMember.copyWith(
                              glowEffectId: _glowEffectId,
                              frameShapeId: entry.key,
                            ),
                            radius: 22,
                            avatarFullPath: previewPath,
                            showColorRing: true,
                            gradientRingTopColor: widget.gradientRingTopColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.value.label,
                          style: const TextStyle(fontSize: 9),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}