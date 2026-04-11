void main() {
  String s1 = '181,448,901.614,82';
  String s2 = '84,489,70819,46';
  String s3 = '50,49,20463,68';
  String s4 = '9,4814,90141,25';
  String s5 = '108,9089,00'; // Q=10 U=8,90 T=89,00

  void test(String numStr) {
    print('Testing $numStr');
    String clean = numStr.replaceAll('.', '');
    for (int i = 1; i < clean.length - 1; i++) {
        for (int j = i + 1; j < clean.length; j++) {
            String qStr = clean.substring(0, i);
            String uStr = clean.substring(i, j);
            String tStr = clean.substring(j);

            int tCommaPos = tStr.indexOf(',');
            if (tCommaPos == -1 || tStr.length - tCommaPos - 1 != 2) continue;
            
            if (uStr.isEmpty || uStr == ',') continue;
            int uCommaPos = uStr.indexOf(',');
            if (uCommaPos != -1 && uCommaPos != uStr.lastIndexOf(',')) continue;
            
            if (qStr.isEmpty || qStr == ',') continue;
            int qCommaPos = qStr.indexOf(',');
            if (qCommaPos != -1 && qCommaPos != qStr.lastIndexOf(',')) continue;

            double qVal = double.parse(qStr.replaceAll(',', '.'));
            double uVal = double.parse(uStr.replaceAll(',', '.'));
            double tVal = double.parse(tStr.replaceAll(',', '.'));

            if ((qVal * uVal - tVal).abs() <= 0.05) {
                print('  Match: Q=$qVal, U=$uVal, T=$tVal');
                return; // Stop at first match
            }
        }
    }
    print('  No match found.');
  }

  test(s1);
  test(s2);
  test(s3);
  test(s4);
  test(s5);
}
