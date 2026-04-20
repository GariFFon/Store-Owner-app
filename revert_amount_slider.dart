import 'dart:io';

void main() {
  final file = File('lib/screens/order_details_screen.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
    RegExp(r'StatefulBuilder\(\s*builder: \(context, setAmountState\) \{\s*double currentVal = double\.tryParse\(amountController\.text\) \?\? 0\.0;\s*if \(currentVal > grandTotal\) currentVal = grandTotal;\s*if \(currentVal < 0\) currentVal = 0;\s*return Container\(\s*padding: const EdgeInsets\.fromLTRB\(16, 4, 16, 8\),\s*decoration: BoxDecoration\(color: Colors\.white, borderRadius: BorderRadius\.circular\(12\), border: Border\.all\(color: const Color\(0xFFE2E8F0\)\)\),\s*child: Column\(\s*crossAxisAlignment: CrossAxisAlignment\.stretch,\s*children: \[\s*TextField\('),
    '''Container(
                                                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                                 decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                                                 child: TextField('''
  );

  content = content.replaceFirst(
    RegExp(r'onChanged: \(val\) => setAmountState\(\(\)\{\}\),\s*keyboardType: const TextInputType\.numberWithOptions\(decimal: false\),'),
    '''keyboardType: const TextInputType.numberWithOptions(decimal: true),'''
  );

  content = content.replaceFirst(
    RegExp(r'\),\s*if \(grandTotal > 0\)\s*SliderTheme\([\s\S]*?divisions: grandTotal\.toInt\(\) > 0 \? grandTotal\.toInt\(\) : 1,\s*activeColor: statusColor,\s*inactiveColor: statusColor\.withOpacity\(0\.2\),\s*onChanged: \(val\) \{\s*setAmountState\(\(\) \{\s*amountController\.text = val\.toInt\(\)\.toString\(\);\s*\}\);\s*\},\s*\),\s*\),\s*\],\s*\)\s*\);\s*\}\s*\),'),
    ''')
                                               ),'''
  );

  content = content.replaceFirst(
    RegExp(r'if \(MediaQuery\.of\(context\)\.viewInsets\.bottom > 0\)\s*SizedBox\([\s\S]*?else\s*SizedBox\('),
    '''SizedBox('''
  );

  file.writeAsStringSync(content);
}
