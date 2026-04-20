import 'dart:io';

void main() {
  final file = File('lib/screens/order_details_screen.dart');
  var content = file.readAsStringSync();

  content = content.replaceFirst(
    RegExp(r'Container\(\s*padding: const EdgeInsets\.symmetric\(horizontal: 16, vertical: 4\),\s*decoration: BoxDecoration\(color: Colors\.white, borderRadius: BorderRadius\.circular\(12\), border: Border\.all\(color: const Color\(0xFFE2E8F0\)\)\),\s*child: TextField\('),
    '''StatefulBuilder(
                                                 builder: (context, setAmountState) {
                                                   double currentVal = double.tryParse(amountController.text) ?? 0.0;
                                                   if (currentVal > grandTotal) currentVal = grandTotal;
                                                   if (currentVal < 0) currentVal = 0;
                                                   
                                                   return Container(
                                                     padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                                     decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                                                     child: Column(
                                                       crossAxisAlignment: CrossAxisAlignment.stretch,
                                                       children: [
                                                         TextField('''
  );

  content = content.replaceFirst(
    RegExp(r'keyboardType: const TextInputType\.numberWithOptions\(decimal: true\),'),
    '''onChanged: (val) => setAmountState((){}),
                                                   keyboardType: const TextInputType.numberWithOptions(decimal: false),'''
  );

  content = content.replaceFirst(
    RegExp(r'filled: false,\s*\)\s*\)\s*\),'),
    '''filled: false,
                                                   )
                                                 ),
                                                 if (grandTotal > 0)
                                                   SliderTheme(
                                                     data: SliderThemeData(
                                                       overlayShape: SliderComponentShape.noOverlay,
                                                       trackShape: const RectangularSliderTrackShape(),
                                                       thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                                                       trackHeight: 4,
                                                     ),
                                                     child: Slider(
                                                       value: currentVal,
                                                       min: 0,
                                                       max: grandTotal,
                                                       divisions: grandTotal.toInt() > 0 ? grandTotal.toInt() : 1,
                                                       activeColor: statusColor,
                                                       inactiveColor: statusColor.withOpacity(0.2),
                                                       onChanged: (val) {
                                                          setAmountState(() {
                                                            amountController.text = val.toInt().toString(); 
                                                          });
                                                       },
                                                     ),
                                                   ),
                                               ],
                                             )
                                           );
                                        }
                                       ),'''
  );

  content = content.replaceFirst(
    RegExp(r'SizedBox\(\s*width: double\.infinity,\s*child: ElevatedButton\(\s*style: ElevatedButton\.styleFrom\(\s*backgroundColor: statusColor,'),
    '''if (MediaQuery.of(context).viewInsets.bottom > 0)
                                               SizedBox(
                                                 width: double.infinity,
                                                 child: ElevatedButton(
                                                   style: ElevatedButton.styleFrom(
                                                     backgroundColor: Colors.white,
                                                     foregroundColor: const Color(0xFF0F172A),
                                                     padding: const EdgeInsets.symmetric(vertical: 18),
                                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                                                     elevation: 0,
                                                   ),
                                                   onPressed: () => FocusScope.of(context).unfocus(),
                                                   child: const TranslatedText('Done / Close Keyboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                                 )
                                               )
                                            else
                                               SizedBox(
                                                 width: double.infinity,
                                                 child: ElevatedButton(
                                                   style: ElevatedButton.styleFrom(
                                                     backgroundColor: statusColor,'''
  );

  file.writeAsStringSync(content);
}
