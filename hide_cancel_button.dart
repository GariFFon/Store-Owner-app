import 'dart:io';

void main() {
  final file = File('lib/screens/order_details_screen.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
    RegExp(r'const SizedBox\(height: 8\),\s*SizedBox\(\s*width: double\.infinity,\s*child: ElevatedButton\(\s*style: ElevatedButton\.styleFrom\(\s*backgroundColor: Colors\.white,[\s\S]*?child: const TranslatedText\(''Cancel'', style: TextStyle\(fontSize: 16, fontWeight: FontWeight\.w700\)\),\s*\)\s*\)'),
    '''if (MediaQuery.of(context).viewInsets.bottom == 0) ...[
                 const SizedBox(height: 8),
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.white,
                       foregroundColor: const Color(0xFF0F172A),
                       padding: const EdgeInsets.symmetric(vertical: 18),
                       shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(12),
                         side: const BorderSide(color: Color(0xFFE2E8F0))
                       ),
                       elevation: 0,
                     ),
                     onPressed: () => Navigator.pop(context),
                     child: const TranslatedText('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                   )
                 )
               ]'''
  );

  file.writeAsStringSync(content);
}
