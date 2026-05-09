import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:arena/core/services/api_service.dart';
import 'package:arena/core/models/course_model.dart';
import 'package:arena/core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class AdminCreateCourseScreen extends StatefulWidget {
  final String? editCourseId;
  const AdminCreateCourseScreen({super.key, this.editCourseId});
  @override
  State<AdminCreateCourseScreen> createState() => _AdminCreateCourseScreenState();
}

class _AdminCreateCourseScreenState extends State<AdminCreateCourseScreen> {
  final _api = ApiService();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  String _category = 'PROGRAMMING';
  bool _isPublished = false;
  bool _isSaving = false;
  bool _isLoadingEdit = false;
  List<int>? _thumbnailBytes;
  String? _thumbnailName;

  // Documents management (edit mode)
  List<CourseDocument> _existingDocs = [];
  final List<_PendingDoc> _pendingDocs = [];
  bool _isUploadingDoc = false;

  bool get _isEdit => widget.editCourseId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadExisting();
  }

  @override
  void dispose() { _titleCtrl.dispose(); _descCtrl.dispose(); _priceCtrl.dispose(); super.dispose(); }

  Future<void> _loadExisting() async {
    setState(() => _isLoadingEdit = true);
    try {
      final data = await _api.getCourseDetail(widget.editCourseId!);
      final c = Course.fromJson(data);
      _titleCtrl.text = c.title;
      _descCtrl.text = c.description;
      _priceCtrl.text = c.price.toStringAsFixed(0);
      _category = c.category;
      _isPublished = c.isPublished;
      // Load docs
      try {
        // Admin bypass: use detail data if available
        final docsData = await _api.getAdminCourses();
        // Actually try loading documents directly
      } catch (_) {}
      if (mounted) setState(() => _isLoadingEdit = false);
    } catch (_) { if (mounted) setState(() => _isLoadingEdit = false); }
  }

  Future<void> _pickThumbnail() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() { _thumbnailBytes = bytes; _thumbnailName = picked.name; });
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false, withData: true);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        final titleCtrl = TextEditingController(text: file.name.split('.').first);
        final docTitle = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Document Title', style: TextStyle(color: Colors.white)),
          content: TextField(controller: titleCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(filled: true, fillColor: const Color(0xFF0F172A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), hintText: 'Enter title', hintStyle: TextStyle(color: Colors.grey.shade600))),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel', style: TextStyle(color: Colors.grey.shade500))),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(titleCtrl.text), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ],
        ));
        if (docTitle != null && docTitle.isNotEmpty) {
          if (_isEdit) {
            // Upload immediately
            setState(() => _isUploadingDoc = true);
            try {
              await _api.uploadCourseDocument(courseId: widget.editCourseId!, fileBytes: file.bytes!, filename: file.name, title: docTitle, order: _existingDocs.length + _pendingDocs.length);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded!'), backgroundColor: Color(0xFF10B981)));
            } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e'), backgroundColor: Colors.red)); }
            if (mounted) setState(() => _isUploadingDoc = false);
          } else {
            setState(() => _pendingDocs.add(_PendingDoc(title: docTitle, filename: file.name, bytes: file.bytes!)));
          }
        }
      }
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().length < 3) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title must be at least 3 characters'), backgroundColor: Colors.red)); return; }
    if (_descCtrl.text.trim().length < 10) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Description must be at least 10 characters'), backgroundColor: Colors.red)); return; }
    setState(() => _isSaving = true);
    try {
      if (_isEdit) {
        await _api.updateCourse(widget.editCourseId!, title: _titleCtrl.text.trim(), description: _descCtrl.text.trim(), category: _category, price: double.tryParse(_priceCtrl.text) ?? 0, isPublished: _isPublished, thumbnailBytes: _thumbnailBytes, thumbnailFilename: _thumbnailName);
      } else {
        final result = await _api.createCourse(title: _titleCtrl.text.trim(), description: _descCtrl.text.trim(), category: _category, price: double.tryParse(_priceCtrl.text) ?? 0, isPublished: _isPublished, thumbnailBytes: _thumbnailBytes, thumbnailFilename: _thumbnailName);
        // Upload pending docs
        final courseId = result['id'] as String;
        for (int i = 0; i < _pendingDocs.length; i++) {
          final d = _pendingDocs[i];
          await _api.uploadCourseDocument(courseId: courseId, fileBytes: d.bytes, filename: d.filename, title: d.title, order: i);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEdit ? 'Course updated!' : 'Course created!'), backgroundColor: const Color(0xFF10B981)));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingEdit) return Scaffold(backgroundColor: const Color(0xFF0F172A), appBar: AppBar(backgroundColor: const Color(0xFF1E293B), iconTheme: const IconThemeData(color: Colors.white)), body: const Center(child: CircularProgressIndicator(color: AppColors.primary)));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Course' : 'Create Course', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B), iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thumbnail picker
          GestureDetector(
            onTap: _pickThumbnail,
            child: Container(
              height: 160, width: double.infinity,
              decoration: BoxDecoration(color: const Color(0xFF1A2332), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withAlpha(40), style: _thumbnailBytes == null ? BorderStyle.solid : BorderStyle.none)),
              child: _thumbnailBytes != null
                ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(Uint8List.fromList(_thumbnailBytes!), fit: BoxFit.cover))
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.primary.withAlpha(120)),
                    const SizedBox(height: 8),
                    Text('Add Thumbnail', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
            ),
          ),
          const SizedBox(height: 24),
          // Title
          _label('Title'),
          const SizedBox(height: 8),
          _textField(_titleCtrl, 'e.g. Master Flutter Development'),
          const SizedBox(height: 20),
          // Description
          _label('Description'),
          const SizedBox(height: 8),
          _textField(_descCtrl, 'Describe what students will learn...', maxLines: 4),
          const SizedBox(height: 20),
          // Category
          _label('Category'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: const Color(0xFF1A2332), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withAlpha(13))),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _category, isExpanded: true, dropdownColor: const Color(0xFF1A2332), style: const TextStyle(color: Colors.white, fontSize: 14),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              items: CourseCategories.labels.entries.map((e) => DropdownMenuItem(value: e.key, child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(CourseCategories.color(e.key)), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 10), Text(e.value),
              ]))).toList(),
              onChanged: (v) { if (v != null) setState(() => _category = v); },
            )),
          ),
          const SizedBox(height: 20),
          // Price
          _label('Price (DT)'),
          const SizedBox(height: 8),
          _textField(_priceCtrl, '0', keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          // Publish toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF1A2332), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withAlpha(13))),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Publish immediately', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(_isPublished ? 'Visible to all users' : 'Saved as draft', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              value: _isPublished, activeColor: const Color(0xFF10B981),
              onChanged: (v) => setState(() => _isPublished = v),
            ),
          ),
          const SizedBox(height: 24),
          // Documents
          Row(children: [
            const Text('Documents', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(
              onTap: _isUploadingDoc ? null : _pickDocument,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.primary.withAlpha(15), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withAlpha(40))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _isUploadingDoc ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)) : const Icon(Icons.attach_file, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(_isUploadingDoc ? 'Uploading...' : 'Add File', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (_pendingDocs.isEmpty && _existingDocs.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF1A2332), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withAlpha(13))),
              child: Center(child: Text('No documents added yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
            )
          else
            ...[
              for (final doc in _existingDocs) _existingDocTile(doc),
              for (int i = 0; i < _pendingDocs.length; i++) _pendingDocTile(i),
            ],
          const SizedBox(height: 32),
          // Save button
          GestureDetector(
            onTap: _isSaving ? null : _save,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withAlpha(60), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Center(child: _isSaving
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(_isEdit ? 'Update Course' : 'Create Course', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600));

  Widget _textField(TextEditingController ctrl, String hint, {int maxLines = 1, TextInputType? keyboardType}) =>
    TextField(controller: ctrl, maxLines: maxLines, keyboardType: keyboardType, style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade600), filled: true, fillColor: const Color(0xFF1A2332),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withAlpha(13))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withAlpha(13))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
      ));

  Widget _pendingDocTile(int idx) {
    final d = _pendingDocs[idx];
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1A2332), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withAlpha(13))),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.insert_drive_file, color: AppColors.primary, size: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(d.filename, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        ])),
        IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 18), onPressed: () => setState(() => _pendingDocs.removeAt(idx))),
      ]),
    );
  }

  Widget _existingDocTile(CourseDocument doc) {
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1A2332), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withAlpha(13))),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF10B981).withAlpha(20), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(doc.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
          onPressed: () async {
            try { await _api.deleteCourseDocument(doc.id); setState(() => _existingDocs.removeWhere((d) => d.id == doc.id));
            } catch (_) {}
          }),
      ]),
    );
  }
}

class _PendingDoc {
  final String title;
  final String filename;
  final List<int> bytes;
  _PendingDoc({required this.title, required this.filename, required this.bytes});
}
