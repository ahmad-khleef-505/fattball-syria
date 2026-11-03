import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/community_post_model.dart';
import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/services/community_service.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

enum _CommunityFilter { all, lostFound, teamSearch }

class CommunityBoardScreen extends ConsumerStatefulWidget {
  const CommunityBoardScreen({super.key, required this.user});

  final UserModel user;

  @override
  ConsumerState<CommunityBoardScreen> createState() =>
      _CommunityBoardScreenState();
}

class _CommunityBoardScreenState extends ConsumerState<CommunityBoardScreen> {
  _CommunityFilter _filter = _CommunityFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مجتمع الملاعب')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CreateCommunityPostScreen(user: widget.user),
          ),
        ),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('منشور جديد'),
      ),
      body: ResponsiveContent(
        maxWidth: 920,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 88),
        child: Column(
          children: [
            SegmentedButton<_CommunityFilter>(
              segments: const [
                ButtonSegment(value: _CommunityFilter.all, label: Text('الكل')),
                ButtonSegment(
                  value: _CommunityFilter.lostFound,
                  icon: Icon(Icons.search),
                  label: Text('مفقودات'),
                ),
                ButtonSegment(
                  value: _CommunityFilter.teamSearch,
                  icon: Icon(Icons.groups_outlined),
                  label: Text('البحث عن فريق'),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) =>
                  setState(() => _filter = selection.first),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ref.watch(communityServiceProvider).watchPosts(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('تعذر تحميل منشورات المجتمع. حاول مجدداً.'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final posts = <CommunityPostModel>[];
                  for (final document in snapshot.data!.docs) {
                    try {
                      final post = CommunityPostModel.fromMap(
                        document.id,
                        document.data(),
                      );
                      if (_filter == _CommunityFilter.all ||
                          (_filter == _CommunityFilter.lostFound &&
                              post.type == CommunityPostType.lostFound) ||
                          (_filter == _CommunityFilter.teamSearch &&
                              post.type == CommunityPostType.teamSearch)) {
                        posts.add(post);
                      }
                    } on FormatException {
                      continue;
                    } on TypeError {
                      continue;
                    }
                  }
                  if (posts.isEmpty) return const _CommunityEmptyState();
                  return ListView.separated(
                    itemCount: posts.length,
                    padding: const EdgeInsets.only(top: 10, bottom: 20),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return _CommunityPostCard(
                        post: post,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CommunityPostDetailsScreen(
                              post: post,
                              user: widget.user,
                            ),
                          ),
                        ),
                      );
                    },
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

class CreateCommunityPostScreen extends ConsumerStatefulWidget {
  const CreateCommunityPostScreen({super.key, required this.user});

  final UserModel user;

  @override
  ConsumerState<CreateCommunityPostScreen> createState() =>
      _CreateCommunityPostScreenState();
}

class _CreateCommunityPostScreenState
    extends ConsumerState<CreateCommunityPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _governorate = TextEditingController(text: 'دمشق');
  final _imagePicker = ImagePicker();
  CommunityPostType _type = CommunityPostType.lostFound;
  String? _fieldId;
  String? _fieldName;
  XFile? _image;
  Uint8List? _imageBytes;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _governorate.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      glassSnackBar(content: Text(text)),
    );
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _message('حجم الصورة يجب ألا يتجاوز 5 ميغابايت.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _image = image;
        _imageBytes = bytes;
      });
    } on PlatformException {
      _message('تعذر اختيار الصورة من الجهاز.');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    String? imageUrl;
    try {
      final postId = await ref.read(communityServiceProvider).createPost(
            authorUid: widget.user.uid,
            authorName: widget.user.name,
            authorRole: widget.user.role,
            type: _type,
            title: _title.text,
            body: _body.text,
            governorate: _governorate.text,
            fieldId: _fieldId,
            fieldName: _fieldName,
          );
      if (_image != null && _imageBytes != null) {
        final mimeType = _image!.mimeType ?? 'image/jpeg';
        final extension = switch (mimeType) {
          'image/png' => 'png',
          'image/webp' => 'webp',
          _ => 'jpg',
        };
        final reference = FirebaseStorage.instance.ref(
          'community_posts/$postId/${widget.user.uid}/image.$extension',
        );
        await reference.putData(
          _imageBytes!,
          SettableMetadata(
            contentType: mimeType,
            customMetadata: {
              'postId': postId,
              'authorUid': widget.user.uid,
            },
          ),
        );
        imageUrl = await reference.getDownloadURL();
        await ref.read(communityServiceProvider).attachImage(
              postId: postId,
              imageUrl: imageUrl,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } on CommunityServiceException catch (error) {
      _message(error.message);
    } on FirebaseException catch (error) {
      _message(
        error.code == 'permission-denied'
            ? 'لا تملك صلاحية نشر هذا المحتوى.'
            : imageUrl == null && _image != null
                ? 'نُشر النص، لكن تعذر إرفاق الصورة. يمكنك فتح البلاغ ونشر الصورة لاحقاً.'
                : 'تعذر نشر المحتوى. تحقق من الاتصال وحاول مجدداً.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldsQuery = FirebaseFirestore.instance
        .collection('fields')
        .where('isActive', isEqualTo: true)
        .where(
          'ownerSubscriptionExpiry',
          isGreaterThan: Timestamp.fromDate(DateTime.now()),
        )
        .snapshots();
    return Scaffold(
      appBar: AppBar(title: const Text('كتابة منشور')),
      body: ResponsiveContent(
        maxWidth: 760,
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<CommunityPostType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'نوع المنشور'),
                items: const [
                  DropdownMenuItem(
                    value: CommunityPostType.lostFound,
                    child: Text('مفقودات وموجودات'),
                  ),
                  DropdownMenuItem(
                    value: CommunityPostType.teamSearch,
                    child: Text('البحث عن فريق / لاعبين'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _type = value;
                            if (_type == CommunityPostType.teamSearch) {
                              _fieldId = null;
                              _fieldName = null;
                            }
                          });
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: _type == CommunityPostType.lostFound
                      ? 'ما الشيء المفقود؟'
                      : 'عنوان البحث',
                  hintText: _type == CommunityPostType.lostFound
                      ? 'حذاء رياضي أسود'
                      : 'فريق يبحث عن لاعبين',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'أدخل عنواناً'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _body,
                maxLines: 5,
                maxLength: 1500,
                decoration: InputDecoration(
                  labelText: _type == CommunityPostType.lostFound
                      ? 'الوصف ومكان/وقت الفقد'
                      : 'تفاصيل الفريق والمركز والموعد',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'أضف بعض التفاصيل'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _governorate,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'المحافظة',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'أدخل المحافظة'
                    : null,
              ),
              if (_type == CommunityPostType.lostFound) ...[
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: fieldsQuery,
                  builder: (context, snapshot) {
                    final fields = <FieldModel>[];
                    for (final document in snapshot.data?.docs ?? []) {
                      try {
                        fields.add(
                          FieldModel.fromMap(document.id, document.data()),
                        );
                      } on FormatException {
                        continue;
                      } on TypeError {
                        continue;
                      }
                    }
                    return DropdownButtonFormField<String?>(
                      value: _fieldId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'الملعب (اختياري)',
                        prefixIcon: Icon(Icons.stadium_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('غير مرتبط بملعب محدد'),
                        ),
                        for (final field in fields)
                          DropdownMenuItem<String?>(
                            value: field.fieldId,
                            child: Text(
                              '${field.name} — ${field.governorate}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (id) {
                              final selected = fields
                                  .where((field) => field.fieldId == id)
                                  .firstOrNull;
                              setState(() {
                                _fieldId = id;
                                _fieldName = selected?.name;
                                if (selected != null) {
                                  _governorate.text = selected.governorate;
                                }
                              });
                            },
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  _image == null ? 'إضافة صورة اختيارية' : 'تغيير الصورة',
                ),
              ),
              if (_imageBytes != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _imageBytes!,
                    height: 190,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish_outlined),
                label: const Text('نشر في المجتمع'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommunityPostDetailsScreen extends ConsumerStatefulWidget {
  const CommunityPostDetailsScreen({
    super.key,
    required this.post,
    required this.user,
  });

  final CommunityPostModel post;
  final UserModel user;

  @override
  ConsumerState<CommunityPostDetailsScreen> createState() =>
      _CommunityPostDetailsScreenState();
}

class _CommunityPostDetailsScreenState
    extends ConsumerState<CommunityPostDetailsScreen> {
  final _replyController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      glassSnackBar(content: Text(text)),
    );
  }

  Future<void> _sendReply() async {
    if (_replyController.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(communityServiceProvider).reply(
            postId: widget.post.id,
            authorUid: widget.user.uid,
            authorName: widget.user.name,
            authorRole: widget.user.role,
            body: _replyController.text,
          );
      _replyController.clear();
    } on CommunityServiceException catch (error) {
      _message(error.message);
    } on FirebaseException {
      _message('تعذر إرسال الرد. تحقق من صلاحيتك والاتصال.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _markResolved() async {
    try {
      await ref.read(communityServiceProvider).markFound(widget.post.id);
      if (mounted) _message('تم تحديث حالة المنشور.');
    } on FirebaseException {
      if (mounted) _message('تعذر تحديث حالة المنشور.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isAuthor = widget.user.uid == post.authorUid;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          post.type == CommunityPostType.lostFound
              ? 'المفقودات والموجودات'
              : 'البحث عن فريق',
        ),
        actions: [
          if (isAuthor &&
              post.type == CommunityPostType.lostFound &&
              post.status == 'active')
            IconButton(
              tooltip: 'تم العثور عليه',
              onPressed: _markResolved,
              icon: const Icon(Icons.task_alt_outlined),
            ),
        ],
      ),
      body: ResponsiveContent(
        maxWidth: 840,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (post.imageUrl != null)
                          Image.network(
                            post.imageUrl!,
                            height: 280,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              height: 120,
                              child: Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                children: [
                                  Chip(
                                    avatar: Icon(
                                      post.type == CommunityPostType.lostFound
                                          ? Icons.search
                                          : Icons.groups_outlined,
                                      size: 18,
                                    ),
                                    label: Text(_typeLabel(post.type)),
                                  ),
                                  if (post.status == 'resolved')
                                    const Chip(
                                      label: Text('تم العثور عليه'),
                                      avatar: Icon(Icons.check_circle_outline),
                                    ),
                                ],
                              ),
                              Text(
                                post.title,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(post.body),
                              const SizedBox(height: 12),
                              Text(
                                '${post.authorName} • ${post.governorate}'
                                '${post.fieldName == null ? '' : ' • ${post.fieldName}'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                DateFormat('yyyy/MM/dd • HH:mm')
                                    .format(post.createdAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'النقاش والردود',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: ref
                        .watch(communityServiceProvider)
                        .watchReplies(post.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Card(
                          child: ListTile(
                            title: Text('تعذر تحميل الردود.'),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final replies = <CommunityReplyModel>[];
                      for (final document in snapshot.data!.docs) {
                        try {
                          replies.add(
                            CommunityReplyModel.fromMap(
                              document.id,
                              document.data(),
                            ),
                          );
                        } on FormatException {
                          continue;
                        } on TypeError {
                          continue;
                        }
                      }
                      if (replies.isEmpty) {
                        return const Card(
                          child: ListTile(
                            leading: Icon(Icons.forum_outlined),
                            title: Text('كن أول من يرد بمعلومة مفيدة.'),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final reply in replies)
                            Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    reply.authorName.isEmpty
                                        ? '؟'
                                        : reply.authorName.characters.first,
                                  ),
                                ),
                                title: Text(reply.authorName),
                                subtitle: Text(
                                  '${reply.body}\n'
                                  '${DateFormat('yyyy/MM/dd • HH:mm').format(reply.createdAt)}',
                                ),
                                isThreeLine: true,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          hintText: 'اكتب رداً مفيداً...',
                          counterText: '',
                        ),
                        onSubmitted: (_) => _sendReply(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'إرسال الرد',
                      onPressed: _sending ? null : _sendReply,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({required this.post, required this.onTap});

  final CommunityPostModel post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLostFound = post.type == CommunityPostType.lostFound;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (post.imageUrl != null)
              Image.network(
                post.imageUrl!,
                height: 170,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 80,
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        avatar: Icon(
                          isLostFound ? Icons.search : Icons.groups_outlined,
                          size: 18,
                        ),
                        label: Text(_typeLabel(post.type)),
                      ),
                      if (post.status == 'resolved')
                        const Chip(label: Text('تم العثور عليه')),
                    ],
                  ),
                  Text(
                    post.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${post.governorate}'
                          '${post.fieldName == null ? '' : ' • ${post.fieldName}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormat('MM/dd').format(post.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chat_bubble_outline, size: 17),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'بواسطة ${post.authorName}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityEmptyState extends StatelessWidget {
  const _CommunityEmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sports_soccer_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'المجتمع يبدأ بمشاركة منك',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'أبلغ عن غرض مفقود، أو اعثر على فريقك القادم.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

String _typeLabel(CommunityPostType type) =>
    type == CommunityPostType.lostFound ? 'مفقودات' : 'البحث عن فريق';
