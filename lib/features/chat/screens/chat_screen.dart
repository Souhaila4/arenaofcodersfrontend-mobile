import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' as stream;

import 'package:arena/core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Helper: detect AttachmentType from a file extension
// ---------------------------------------------------------------------------
stream.AttachmentType _typeFromExt(String? ext) {
  if (ext == null) return stream.AttachmentType.file;
  final e = ext.toLowerCase();
  if ({'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'}.contains(e)) {
    return stream.AttachmentType.image;
  }
  if ({'mp4', 'mov', 'avi', 'mkv', 'webm'}.contains(e)) {
    return stream.AttachmentType.video;
  }
  return stream.AttachmentType.file;
}

String? _extFromPath(String? path) => path?.split('.').last;

// ---------------------------------------------------------------------------
// ChatScreen
// ---------------------------------------------------------------------------
class ChatScreen extends StatelessWidget {
  final String roomId;
  final String roomName;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  /// Shows the attachment picker, re-injecting [StreamChatTheme] into the
  /// new route context (modal bottom sheets create a new route that does NOT
  /// inherit InheritedWidgets from the calling page).
  Future<void> _showAttachmentPicker(BuildContext context) async {
    final streamTheme = stream.StreamChatTheme.of(context);
    final channel = stream.StreamChannel.of(context).channel;

    if (!channel.canUploadFile) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: streamTheme.colorTheme.inputBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return stream.StreamChatTheme(
          data: streamTheme,
          child: _AttachmentPickerSheet(channel: channel),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final streamTheme = isDark
        ? stream.StreamChatThemeData.dark()
        : stream.StreamChatThemeData.light();

    return stream.StreamChatTheme(
      data: streamTheme,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F141C) : Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1A2332) : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios,
                color: isDark ? Colors.white : Colors.black87, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                roomName,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Live',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.video_call_outlined,
                  color: AppColors.accentCyan),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Video call coming soon')),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: stream.StreamMessageListView(
                messageFilter: (m) => !m.shadowed,
                showFloatingDateDivider: true,
                // Custom builder: inline image preview + download button
                messageBuilder: (ctx, details, messages, defaultMessage) {
                  final msg = details.message;
                  if (msg.attachments.isNotEmpty) {
                    return _MessageWithAttachments(
                      details: details,
                      defaultWidget: defaultMessage,
                    );
                  }
                  return defaultMessage;
                },
              ),
            ),
            Builder(
              builder: (innerContext) => stream.StreamMessageInput(
                preMessageSending: (m) async => m,
                attachmentButtonBuilder: (ctx, defaultButton) {
                  return IconButton(
                    icon: Icon(
                      Icons.attach_file,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                    onPressed: () => _showAttachmentPicker(innerContext),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Attachment Picker Bottom Sheet
// ---------------------------------------------------------------------------
class _AttachmentPickerSheet extends StatefulWidget {
  final stream.Channel channel;
  const _AttachmentPickerSheet({required this.channel});

  @override
  State<_AttachmentPickerSheet> createState() => _AttachmentPickerSheetState();
}

class _AttachmentPickerSheetState extends State<_AttachmentPickerSheet> {
  bool _loading = false;
  // _pick is defined via the extension below to support optional allowedExtensions.

  @override
  Widget build(BuildContext context) {
    final colorTheme = stream.StreamChatTheme.of(context).colorTheme;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorTheme.disabled,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Joindre un fichier',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorTheme.textHighEmphasis,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorTheme.accentPrimary.withOpacity(0.15),
              child: Icon(Icons.image, color: colorTheme.accentPrimary),
            ),
            title: const Text('Images / Vidéos'),
            subtitle: const Text('JPG, PNG, GIF, MP4…'),
            onTap: () => _pick(FileType.media),
          ),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red.withOpacity(0.15),
              child: const Icon(Icons.picture_as_pdf, color: Colors.red),
            ),
            title: const Text('PDF'),
            subtitle: const Text('Fichiers PDF'),
            onTap: () => _pick(
              FileType.custom,
              allowedExtensions: ['pdf'],
            ),
          ),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.15),
              child: const Icon(Icons.insert_drive_file, color: Colors.blue),
            ),
            title: const Text('Tous les fichiers'),
            subtitle: const Text('Documents, archives…'),
            onTap: () => _pick(FileType.any),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

extension on _AttachmentPickerSheetState {
  Future<void> _pick(FileType type, {List<String>? allowedExtensions}) async {
    setState(() => _loading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: true,
        withData: false,
      );
      if (result == null || !mounted) return;
      Navigator.pop(context);

      final attachments = result.files.map((f) {
        final ext = _extFromPath(f.path);
        final attachType = _typeFromExt(ext);
        return stream.Attachment(
          type: attachType,
          file: stream.AttachmentFile(
            path: f.path,
            size: f.size,
            name: f.name,
          ),
        );
      }).toList();

      await widget.channel
          .sendMessage(stream.Message(attachments: attachments));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Message with inline image preview + download button for files/PDFs
// ---------------------------------------------------------------------------
class _MessageWithAttachments extends StatelessWidget {
  final stream.MessageDetails details;
  final Widget defaultWidget;

  const _MessageWithAttachments({
    required this.details,
    required this.defaultWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Stream's default message widget already shows images inline.
    // We only need to add the download/open capability for non-image files.
    return Column(
      crossAxisAlignment: details.isMyMessage
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        defaultWidget,
        for (final att in details.message.attachments)
          if (att.type != stream.AttachmentType.image &&
              att.type != stream.AttachmentType.giphy &&
              (att.assetUrl != null || att.imageUrl != null))
            _FileCard(attachment: att),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// File card with download + open
// ---------------------------------------------------------------------------
class _FileCard extends StatefulWidget {
  final stream.Attachment attachment;
  const _FileCard({required this.attachment});

  @override
  State<_FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<_FileCard> {
  double? _progress; // null = idle, 0-1 = downloading
  String? _localPath;

  String get _url =>
      widget.attachment.assetUrl ??
      widget.attachment.imageUrl ??
      '';

  String get _filename =>
      widget.attachment.title ?? _url.split('/').last;

  Future<void> _downloadAndOpen() async {
    if (_localPath != null) {
      await OpenFilex.open(_localPath!);
      return;
    }
    setState(() => _progress = 0);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$_filename';
      await Dio().download(
        _url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );
      if (mounted) {
        setState(() {
          _localPath = savePath;
          _progress = null;
        });
        await OpenFilex.open(savePath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _progress = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Téléchargement échoué : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorTheme = stream.StreamChatTheme.of(context).colorTheme;
    final isPdf = _filename.toLowerCase().endsWith('.pdf');

    return GestureDetector(
      onTap: _downloadAndOpen,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorTheme.appBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorTheme.borders),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
              color: isPdf ? Colors.red : colorTheme.accentPrimary,
              size: 28,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _filename,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorTheme.textHighEmphasis,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_progress != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 3,
                        backgroundColor: colorTheme.disabled,
                        color: colorTheme.accentPrimary,
                      ),
                    )
                  else
                    Text(
                      _localPath != null ? 'Ouvrir' : 'Appuyer pour télécharger',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorTheme.textLowEmphasis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _localPath != null ? Icons.open_in_new : Icons.download,
              size: 20,
              color: colorTheme.accentPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
