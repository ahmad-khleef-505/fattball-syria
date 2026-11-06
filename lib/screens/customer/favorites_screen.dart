import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/field_model.dart';
import 'package:fattball/models/user_model.dart';
import 'package:fattball/screens/customer/field_details.dart';
import 'package:fattball/widgets/responsive_scaffold.dart';
import 'package:flutter/material.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.customer});

  final UserModel customer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ملاعبي المفضلة')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('favorites')
            .where('userId', isEqualTo: customer.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('تعذر تحميل المفضلة.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final favDocs = snapshot.data?.docs ?? [];
          if (favDocs.isEmpty) {
            return const Center(
              child: Text('لم تقم بإضافة أي ملعب للمفضلة بعد.'),
            );
          }

          // جلب تفاصيل الملاعب من خلال معرفاتها
          final fieldIds = favDocs.map((doc) => doc['fieldId'] as String).toList();
          
          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('fields')
                .where(FieldPath.documentId, whereIn: fieldIds)
                .get(),
            builder: (context, fieldSnapshot) {
              if (fieldSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!fieldSnapshot.hasData || fieldSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text('لا توجد تفاصيل متاحة لهذه الملاعب.'));
              }

              final fields = fieldSnapshot.data!.docs.map((doc) {
                return FieldModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: fields.length,
                itemBuilder: (context, index) {
                  final field = fields[index];
                  return Card(
                    child: ListTile(
                      leading: field.images.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                field.images.first,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                              ),
                            )
                          : const Icon(Icons.sports_soccer, size: 40),
                      title: Text(field.name),
                      subtitle: Text('${field.governorate} - ${field.district}'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FieldDetails(field: field, customer: customer),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}