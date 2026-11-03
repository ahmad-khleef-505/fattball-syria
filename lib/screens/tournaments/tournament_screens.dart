import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';

import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/tournament_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/services/tournament_service.dart';
import 'package:fattball/widgets/glass_snack_bar.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

DateTime _damascusAt(DateTime date, int hour, [int minute = 0]) {
  timezone_data.initializeTimeZones();
  return timezone.TZDateTime(
    timezone.getLocation('Asia/Damascus'),
    date.year,
    date.month,
    date.day,
    hour,
    minute,
  );
}

DateTime _damascusTime(DateTime value) {
  timezone_data.initializeTimeZones();
  return timezone.TZDateTime.from(
    value,
    timezone.getLocation('Asia/Damascus'),
  );
}

String _damascusDate(DateTime value) =>
    DateFormat('yyyy/MM/dd').format(_damascusTime(value));

class OwnerTournamentsScreen extends ConsumerWidget {
  const OwnerTournamentsScreen({super.key, required this.owner});

  final UserModel owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(tournamentServiceProvider);
    final tournaments = service.watchTournaments(ownerId: owner.uid);
    final ownedFields = FirebaseFirestore.instance
        .collection('fields')
        .where('ownerId', isEqualTo: owner.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة البطولات')),
      floatingActionButton: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ownedFields,
        builder: (context, snapshot) {
          final fields = <FieldModel>[];
          for (final document in snapshot.data?.docs ?? []) {
            try {
              fields.add(FieldModel.fromMap(document.id, document.data()));
            } on FormatException {
              continue;
            } on TypeError {
              continue;
            }
          }
          return FloatingActionButton.extended(
            onPressed: fields.isEmpty
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CreateTournamentScreen(
                          owner: owner,
                          fields: fields,
                        ),
                      ),
                    ),
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text('إنشاء بطولة'),
          );
        },
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: tournaments,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('تعذر تحميل البطولات.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = <TournamentModel>[];
          for (final document in snapshot.data!.docs) {
            try {
              items.add(TournamentModel.fromMap(document.id, document.data()));
            } on FormatException {
              continue;
            } on TypeError {
              continue;
            }
          }
          if (items.isEmpty) {
            return const Center(child: Text('لم تنشئ أي بطولة بعد.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _TournamentCard(
              tournament: items[index],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TournamentDetailsScreen(
                    tournament: items[index],
                    user: owner,
                    isOwner: true,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class TournamentListScreen extends ConsumerWidget {
  const TournamentListScreen({super.key, required this.customer});

  final UserModel customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('البطولات والدوريات')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ref.watch(tournamentServiceProvider).watchTournaments(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('تعذر تحميل البطولات حالياً.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = <TournamentModel>[];
          for (final document in snapshot.data!.docs) {
            try {
              final tournament =
                  TournamentModel.fromMap(document.id, document.data());
              if (tournament.status == 'registration' ||
                  tournament.status == 'scheduled') {
                items.add(tournament);
              }
            } on FormatException {
              continue;
            } on TypeError {
              continue;
            }
          }
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('لا توجد بطولات مفتوحة أو جداول منشورة حالياً.'),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = AppBreakpoints.gridColumns(constraints.maxWidth);
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 210,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) => _TournamentCard(
                  tournament: items[index],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TournamentDetailsScreen(
                        tournament: items[index],
                        user: customer,
                        isOwner: false,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CreateTournamentScreen extends ConsumerStatefulWidget {
  const CreateTournamentScreen({
    super.key,
    required this.owner,
    required this.fields,
  });

  final UserModel owner;
  final List<FieldModel> fields;

  @override
  ConsumerState<CreateTournamentScreen> createState() =>
      _CreateTournamentScreenState();
}

class _CreateTournamentScreenState
    extends ConsumerState<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _teams = TextEditingController(text: '8');
  final _fee = TextEditingController(text: '0');
  final _prize = TextEditingController();
  FieldModel? _field;
  DateTime? _deadline;
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    timezone_data.initializeTimeZones();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _teams.dispose();
    _fee.dispose();
    _prize.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? current, String title) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: current ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      helpText: title,
      confirmText: 'اختيار',
      cancelText: 'إلغاء',
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final field = _field;
    final deadline = _deadline;
    final start = _start;
    final end = _end;
    if (field == null || deadline == null || start == null || end == null) {
      _message('اختر الملعب ومواعيد التسجيل والبطولة.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(tournamentServiceProvider).createTournament(
            ownerId: widget.owner.uid,
            fieldId: field.fieldId,
            fieldName: field.name,
            openTime: field.openTime,
            closeTime: field.closeTime,
            name: _name.text,
            description: _description.text,
            maxTeams: int.parse(_teams.text),
            entryFeeUsd: double.parse(_fee.text),
            prizeDescription: _prize.text,
            registrationDeadline: _damascusAt(deadline, 16, 59),
            startAt: _damascusAt(start, 17),
            endAt: _damascusAt(end, 23, 59),
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on TournamentServiceException catch (error) {
      _message(error.message);
    } on FirebaseException catch (error) {
      _message(
        error.code == 'permission-denied'
            ? 'تأكد من أن اشتراكك نشط وأن الملعب تابع لك.'
            : 'تعذر حفظ البطولة. تحقق من الاتصال وحاول مجدداً.',
      );
    } on FormatException {
      _message('أدخل أرقاماً صحيحة لعدد الفرق والرسوم.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      glassSnackBar(content: Text(value)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء بطولة')),
      body: ResponsiveContent(
        maxWidth: 760,
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<FieldModel>(
                value: _field,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'الملعب المستضيف',
                  prefixIcon: Icon(Icons.stadium_outlined),
                ),
                items: widget.fields
                    .map(
                      (field) => DropdownMenuItem(
                        value: field,
                        child: Text(field.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _field = value),
                validator: (value) => value == null ? 'اختر الملعب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'اسم البطولة',
                  hintText: 'دوري رمضان الخماسي',
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'أدخل الاسم' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'وصف البطولة'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _teams,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'أقصى عدد للفرق'),
                      validator: (value) {
                        final count = int.tryParse(value ?? '');
                        return count == null || count < 2 || count > 24
                            ? 'من 2 إلى 24'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fee,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'رسوم الفريق (USD)',
                      ),
                      validator: (value) {
                        final fee = double.tryParse(value ?? '');
                        return fee == null || fee < 0
                            ? 'أدخل رسوماً صحيحة'
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _prize,
                decoration: const InputDecoration(
                  labelText: 'الجوائز',
                  hintText: 'كأس + جائزة مالية...',
                ),
              ),
              const SizedBox(height: 16),
              _DateButton(
                label: 'آخر موعد للتسجيل',
                value: _deadline,
                onTap: () async {
                  final value = await _pickDate(_deadline, 'آخر موعد للتسجيل');
                  if (value != null) setState(() => _deadline = value);
                },
              ),
              _DateButton(
                label: 'بداية البطولة',
                value: _start,
                onTap: () async {
                  final value = await _pickDate(_start, 'بداية البطولة');
                  if (value != null) setState(() => _start = value);
                },
              ),
              _DateButton(
                label: 'نهاية البطولة',
                value: _end,
                onTap: () async {
                  final value = await _pickDate(_end, 'نهاية البطولة');
                  if (value != null) setState(() => _end = value);
                },
              ),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'الدفع نقداً أو عبر شام كاش/سيرياتيل كاش خارج التطبيق. '
                    'يُرسل إثبات التحويل ويعتمده صاحب الملعب؛ لا توجد بوابة دفع إلكتروني مفعّلة.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('نشر البطولة وفتح التسجيل'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TournamentDetailsScreen extends ConsumerWidget {
  const TournamentDetailsScreen({
    super.key,
    required this.tournament,
    required this.user,
    required this.isOwner,
  });

  final TournamentModel tournament;
  final UserModel user;
  final bool isOwner;

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      glassSnackBar(content: Text(text)),
    );
  }

  Future<void> _createSchedule(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final count = await ref
          .read(tournamentServiceProvider)
          .createRoundRobinSchedule(tournament);
      if (context.mounted) {
        _message(context, 'تم إنشاء جدول من $count مباراة.');
        Navigator.of(context).pop();
      }
    } on TournamentServiceException catch (error) {
      if (context.mounted) _message(context, error.message);
    } on FirebaseException {
      if (context.mounted) {
        _message(context, 'تعذر إنشاء الجدول. تحقق من الصلاحيات.');
      }
    }
  }

  Future<void> _editScore(
    BuildContext context,
    WidgetRef ref,
    TournamentMatch match,
  ) async {
    final home = TextEditingController(text: '${match.homeScore ?? ''}');
    final away = TextEditingController(text: '${match.awayScore ?? ''}');
    final formKey = GlobalKey<FormState>();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل نتيجة المباراة'),
        content: Form(
          key: formKey,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: home,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: match.homeTeamName),
                  validator: (value) =>
                      int.tryParse(value ?? '') == null ? 'أدخل النتيجة' : null,
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(':'),
              ),
              Expanded(
                child: TextFormField(
                  controller: away,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: match.awayTeamName),
                  validator: (value) =>
                      int.tryParse(value ?? '') == null ? 'أدخل النتيجة' : null,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (save != true) {
      home.dispose();
      away.dispose();
      return;
    }
    try {
      await ref.read(tournamentServiceProvider).saveMatchResult(
            tournamentId: tournament.id,
            match: match,
            homeScore: int.parse(home.text),
            awayScore: int.parse(away.text),
          );
      if (context.mounted) _message(context, 'تم حفظ نتيجة المباراة.');
    } on TournamentServiceException catch (error) {
      if (context.mounted) _message(context, error.message);
    } on FirebaseException {
      if (context.mounted) _message(context, 'تعذر حفظ النتيجة.');
    } finally {
      home.dispose();
      away.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(tournamentServiceProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tournament.name)),
      body: ResponsiveContent(
        maxWidth: 900,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: ListView(
          children: [
            _TournamentHeader(tournament: tournament),
            const SizedBox(height: 16),
            if (!isOwner && tournament.status == 'registration')
              _RegisterTeamCard(tournament: tournament, user: user),
            if (isOwner && tournament.status == 'registration') ...[
              _OwnerTeamsPanel(tournament: tournament),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _createSchedule(context, ref),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('إغلاق التسجيل وإنشاء جدول الدوري'),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'جدول المباريات والنتائج',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: service.watchMatches(tournament.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('تعذر تحميل جدول المباريات.'),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final matches = <TournamentMatch>[];
                for (final document in snapshot.data!.docs) {
                  try {
                    matches.add(
                      TournamentMatch.fromMap(document.id, document.data()),
                    );
                  } on FormatException {
                    continue;
                  } on TypeError {
                    continue;
                  }
                }
                if (matches.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'يُنشر جدول الدوري بعد اعتماد رسوم فريقين على الأقل وإغلاق التسجيل.',
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final match in matches)
                      _MatchCard(
                        match: match,
                        isOwner: isOwner,
                        onEdit: () => _editScore(context, ref, match),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterTeamCard extends ConsumerStatefulWidget {
  const _RegisterTeamCard({required this.tournament, required this.user});
  final TournamentModel tournament;
  final UserModel user;

  @override
  ConsumerState<_RegisterTeamCard> createState() => _RegisterTeamCardState();
}

class _RegisterTeamCardState extends ConsumerState<_RegisterTeamCard> {
  final _teamName = TextEditingController();
  final _picker = ImagePicker();
  String _method = 'cash';
  XFile? _receipt;
  Uint8List? _receiptBytes;
  bool _cashConfirmed = false;
  bool _saving = false;

  @override
  void dispose() {
    _teamName.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      glassSnackBar(content: Text(text)),
    );
  }

  Future<void> _chooseReceipt() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _message('يجب ألا يتجاوز حجم صورة الإيصال 5 ميغابايت.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _receipt = image;
      _receiptBytes = bytes;
    });
  }

  Future<String?> _uploadReceipt() async {
    if (_receipt == null || _receiptBytes == null) return null;
    final extension = switch (_receipt!.mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path = 'tournament_receipts/${widget.tournament.id}/'
        '${widget.user.uid}/receipt.$extension';
    final reference = FirebaseStorage.instance.ref(path);
    await reference.putData(
      _receiptBytes!,
      SettableMetadata(
        contentType: _receipt!.mimeType ?? 'image/jpeg',
        customMetadata: {
          'tournamentId': widget.tournament.id,
          'captainUid': widget.user.uid,
        },
      ),
    );
    return reference.getDownloadURL();
  }

  Future<void> _register() async {
    if (_teamName.text.trim().isEmpty) {
      _message('أدخل اسم الفريق.');
      return;
    }
    if (_method == 'cash' && !_cashConfirmed) {
      _message('أكد دفع الرسوم نقداً لصاحب الملعب.');
      return;
    }
    if (_method != 'cash' && _receipt == null) {
      _message('ارفع صورة إشعار التحويل.');
      return;
    }
    setState(() => _saving = true);
    try {
      final receiptUrl = _method == 'cash' ? null : await _uploadReceipt();
      await ref.read(tournamentServiceProvider).registerTeam(
            tournament: widget.tournament,
            captainUid: widget.user.uid,
            captainName: widget.user.name,
            teamName: _teamName.text,
            paymentMethod: _method,
            receiptUrl: receiptUrl,
          );
      if (mounted) {
        _message('تم إرسال التسجيل، وبانتظار اعتماد الرسوم من المالك.');
      }
    } on TournamentServiceException catch (error) {
      _message(error.message);
    } on FirebaseException {
      _message('تعذر التسجيل أو رفع الإيصال. تحقق من الاتصال والصلاحيات.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myEntry = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournament.id)
        .collection('teams')
        .doc(widget.user.uid)
        .snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: myEntry,
      builder: (context, snapshot) {
        if (snapshot.data?.exists == true) {
          final status = snapshot.data!.data()?['paymentStatus'];
          final message = switch (status) {
            'paid' => 'تم اعتماد رسوم فريقك. تابع جدول المباريات.',
            'rejected' => 'لم يعتمد المالك إثبات الرسوم. تواصل معه للتوضيح.',
            _ => 'تم تسجيل فريقك، والرسوم بانتظار مراجعة صاحب الملعب.',
          };
          return Card(
            child: ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(message),
            ),
          );
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'سجّل فريقك',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'رسوم الاشتراك: ${widget.tournament.entryFeeUsd.toStringAsFixed(2)} USD للفريق',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _teamName,
                  decoration: const InputDecoration(labelText: 'اسم الفريق'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _method,
                  decoration:
                      const InputDecoration(labelText: 'طريقة دفع الرسوم'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نقداً')),
                    DropdownMenuItem(
                      value: 'sham_cash',
                      child: Text('شام كاش'),
                    ),
                    DropdownMenuItem(
                      value: 'syriatel_cash',
                      child: Text('سيرياتيل كاش'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _method = value;
                            _receipt = null;
                            _receiptBytes = null;
                            _cashConfirmed = false;
                          });
                        },
                ),
                if (_method == 'cash')
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _cashConfirmed,
                    onChanged: _saving
                        ? null
                        : (value) =>
                            setState(() => _cashConfirmed = value ?? false),
                    title: const Text('أؤكد تسليم الرسوم نقداً للمالك.'),
                    controlAffinity: ListTileControlAffinity.leading,
                  )
                else ...[
                  const SizedBox(height: 8),
                  const Text(
                    'حوّل الرسوم إلى صاحب الملعب خارج التطبيق وارفع صورة الإشعار.',
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _chooseReceipt,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(
                      _receipt == null ? 'رفع إثبات التحويل' : 'تغيير الإيصال',
                    ),
                  ),
                  if (_receiptBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _receiptBytes!,
                        height: 130,
                        fit: BoxFit.cover,
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _register,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.group_add_outlined),
                  label: const Text('إرسال طلب التسجيل'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OwnerTeamsPanel extends ConsumerWidget {
  const _OwnerTeamsPanel({required this.tournament});
  final TournamentModel tournament;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(tournamentServiceProvider);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.watchTeams(tournament.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Card(child: ListTile(title: Text('تعذر تحميل الفرق.')));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final teams = snapshot.data!.docs
            .map((doc) => TournamentTeam.fromMap(doc.id, doc.data()))
            .toList();
        return Card(
          child: ExpansionTile(
            title:
                Text('الفرق المسجلة (${teams.length}/${tournament.maxTeams})'),
            children: [
              if (teams.isEmpty)
                const ListTile(title: Text('لا توجد طلبات تسجيل بعد.')),
              for (final team in teams)
                ListTile(
                  title: Text(team.teamName),
                  subtitle: Text(
                    '${team.captainName} • ${_paymentLabel(team.paymentMethod)} • '
                    '${_statusLabel(team.paymentStatus)}',
                  ),
                  trailing: team.paymentStatus == 'pending'
                      ? Wrap(
                          children: [
                            if (team.receiptUrl != null)
                              IconButton(
                                tooltip: 'عرض إيصال التحويل',
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (context) => Dialog(
                                    child: InteractiveViewer(
                                      child: Image.network(team.receiptUrl!),
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.receipt_long_outlined),
                              ),
                            IconButton(
                              tooltip: 'اعتماد الرسوم',
                              onPressed: () async {
                                try {
                                  await service.reviewPayment(
                                    tournamentId: tournament.id,
                                    teamId: team.id,
                                    approved: true,
                                  );
                                } on FirebaseException {
                                  if (context.mounted) _showError(context);
                                }
                              },
                              icon: const Icon(Icons.check_circle_outline),
                            ),
                            IconButton(
                              tooltip: 'رفض الإثبات',
                              onPressed: () async {
                                try {
                                  await service.reviewPayment(
                                    tournamentId: tournament.id,
                                    teamId: team.id,
                                    approved: false,
                                  );
                                } on FirebaseException {
                                  if (context.mounted) _showError(context);
                                }
                              },
                              icon: const Icon(Icons.cancel_outlined),
                            ),
                          ],
                        )
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }

  String _paymentLabel(String method) => switch (method) {
        'sham_cash' => 'شام كاش',
        'syriatel_cash' => 'سيرياتيل كاش',
        _ => 'نقداً',
      };

  String _statusLabel(String status) => switch (status) {
        'paid' => 'معتمد',
        'rejected' => 'مرفوض',
        _ => 'بانتظار الاعتماد',
      };

  void _showError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      glassSnackBar(content: const Text('تعذر تحديث حالة الدفع.')),
    );
  }
}

class _TournamentHeader extends StatelessWidget {
  const _TournamentHeader({required this.tournament});
  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF00A85A)],
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.emoji_events, color: Colors.white, size: 38),
            const SizedBox(height: 8),
            Text(
              tournament.name,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            Text(
              '${tournament.fieldName} • ${_state(tournament.status)}',
              style: const TextStyle(color: Colors.white),
            ),
            if (tournament.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                tournament.description,
                style: const TextStyle(color: Colors.white),
              ),
            ],
            const Divider(color: Colors.white54, height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _HeaderFact(
                  icon: Icons.groups_outlined,
                  text:
                      '${tournament.registeredTeams}/${tournament.maxTeams} فريق',
                ),
                _HeaderFact(
                  icon: Icons.payments_outlined,
                  text: '${tournament.entryFeeUsd.toStringAsFixed(2)} USD',
                ),
                _HeaderFact(
                  icon: Icons.calendar_month_outlined,
                  text: '${_damascusDate(tournament.startAt)} - '
                      '${_damascusDate(tournament.endAt)}',
                ),
              ],
            ),
            if (tournament.prizeDescription.isNotEmpty) ...[
              const SizedBox(height: 10),
              _HeaderFact(
                icon: Icons.workspace_premium_outlined,
                text: tournament.prizeDescription,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _state(String status) =>
      status == 'registration' ? 'التسجيل مفتوح' : 'الجدول منشور';

}

class _HeaderFact extends StatelessWidget {
  const _HeaderFact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      );
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.isOwner,
    required this.onEdit,
  });

  final TournamentMatch match;
  final bool isOwner;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              child: Text('${match.round}'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${match.homeTeamName}  ×  ${match.awayTeamName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEE d MMM • HH:mm')
                        .format(_damascusTime(match.scheduledAt)),
                  ),
                ],
              ),
            ),
            if (match.status == 'completed')
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${match.homeScore} - ${match.awayScore}'),
              )
            else
              const Chip(label: Text('قادمة')),
            if (isOwner)
              IconButton(
                tooltip: 'تسجيل النتيجة',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_note_outlined),
              ),
          ],
        ),
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.tournament, required this.onTap});
  final TournamentModel tournament;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_outlined, size: 28),
                  const Spacer(),
                  Chip(
                    label: Text(
                      tournament.status == 'registration'
                          ? 'التسجيل مفتوح'
                          : 'الجدول منشور',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tournament.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(tournament.fieldName),
              const Spacer(),
              Text(
                '${tournament.maxTeams} فريق • '
                '${tournament.entryFeeUsd.toStringAsFixed(2)} USD',
              ),
              const SizedBox(height: 6),
              Text(
                'تبدأ ${_damascusDate(tournament.startAt)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.event_outlined),
        label: Text(
          value == null
              ? label
              : '$label: ${DateFormat('yyyy/MM/dd').format(value!)}',
        ),
      ),
    );
  }
}
