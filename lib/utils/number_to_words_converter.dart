// lib/utils/number_to_words_converter.dart

// ملاحظة: هذه الدالة هي نسخة مبسطة وتتعامل مع الأرقام الإيجابية حتى البلايين.
// قد تحتاج إلى مكتبة خارجية أو دالة أكثر تعقيدًا للتعامل مع الأرقام الكبيرة جدًا
// أو الفواصل العشرية المعقدة أو اللغات المتعددة بشكل شامل.

// ✅ تم تعديلها لترجع الكلمات فقط، والكنترولر يضيف العملة و"لا غير"
String convertNumberToWordsArabic(double number) {
  if (number < 0) {
    return 'سالب ' + convertNumberToWordsArabic(number.abs());
  }
  if (number == 0) {
    return 'صفر'; // ترجع "صفر" فقط
  }

  int integerPart = number.truncate(); // الجزء الصحيح
  // التأكد من أن الجزء العشري يتم تقريبه بشكل صحيح إلى رقمين عشريين
  int decimalPart = ((number - integerPart) * 100).round(); // الجزء العشري (أول خانتين)

  String integerWords = _convertIntegerToWords(integerPart);
  String result = '';

  if (integerPart > 0) {
    result += integerWords;
  }

  if (decimalPart > 0) {
    String decimalWords = _convertIntegerToWords(decimalPart);
    if (integerPart > 0) {
      result += ' و';
    }
    result += '$decimalWords '; // الآن ستظهر "خمسون فلس"
  }

  return result.trim();
}

// ✅ تم دمج القوائم هنا لتسهيل الوصول إليها ولتكون خاصة بهذه الدالة
String _convertIntegerToWords(int number) {
  if (number == 0) return 'صفر';

  // قوائم الوحدات
  final units = [
    '', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة'
  ];
  // أرقام 10-19: فهرس 0 فارغ، فهرس 10 هو "عشرة" وهكذا.
  // تم تصحيح الفهرسة هنا، teens[0] فارغ، teens[1] هو "أحد عشر" (من 11-19)
  final teens = [
    'عشرة',      // 10
    'أحد عشر',   // 11
    'اثنا عشر',  // 12
    'ثلاثة عشر', // 13
    'أربعة عشر', // 14
    'خمسة عشر',  // 15
    'ستة عشر',   // 16
    'سبعة عشر',  // 17
    'ثمانية عشر', // 18
    'تسعة عشر'   // 19
  ];
  final tens = [
    '', 'عشرة', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون'
  ];
  final hundreds = [
    '', 'مائة', 'مائتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة', 'ستمائة', 'سبعمائة', 'ثمانمائة', 'تسعمائة'
  ];

  String words = '';
  int tempNumber = number;

  // التعامل مع البلايين (Giga)
  if (tempNumber >= 1000000000) {
    int billions = tempNumber ~/ 1000000000;
    if (billions == 1) {
      words += 'مليار '; // أو "بليون" حسب التفضيل
    } else if (billions == 2) {
      words += 'ملياران ';
    } else if (billions >= 3 && billions <= 10) {
      words += '${_convertIntegerToWords(billions)} مليارات ';
    } else {
      words += '${_convertIntegerToWords(billions)} مليار ';
    }
    tempNumber %= 1000000000;
    if (tempNumber > 0) {
      words += 'و';
    }
  }

  // التعامل مع الملايين (Mega)
  if (tempNumber >= 1000000) {
    int millions = tempNumber ~/ 1000000;
    if (millions == 1) {
      words += 'مليون ';
    } else if (millions == 2) {
      words += 'مليونان ';
    } else if (millions >= 3 && millions <= 10) {
      words += '${_convertIntegerToWords(millions)} ملايين ';
    } else {
      words += '${_convertIntegerToWords(millions)} مليون ';
    }
    tempNumber %= 1000000;
    if (tempNumber > 0) {
      words += 'و';
    }
  }

  // التعامل مع الآلاف (Kilo)
  if (tempNumber >= 1000) {
    int thousands = tempNumber ~/ 1000;
    if (thousands == 1) {
      words += 'ألف ';
    } else if (thousands == 2) {
      words += 'ألفان ';
    } else if (thousands >= 3 && thousands <= 10) {
      words += '${_convertIntegerToWords(thousands)} آلاف ';
    } else {
      words += '${_convertIntegerToWords(thousands)} ألف ';
    }
    tempNumber %= 1000;
    if (tempNumber > 0) {
      words += 'و';
    }
  }

  // التعامل مع المئات
  if (tempNumber >= 100) {
    words += hundreds[tempNumber ~/ 100];
    tempNumber %= 100;
    if (tempNumber > 0) {
      words += ' و';
    }
  }

  // التعامل مع العشرات والوحدات
  if (tempNumber >= 20) { // الأعداد من 20 إلى 99
    if (tempNumber % 10 != 0) {
      words += units[tempNumber % 10] + ' و';
    }
    words += tens[tempNumber ~/ 10];
  } else if (tempNumber >= 10) { // الأعداد من 10 إلى 19
    // هنا يجب أن يكون tempNumber >= 10 و <= 19
    // teens[0] هو "عشرة" (لـ 10)، teens[1] هو "أحد عشر" (لـ 11) وهكذا
    // لذلك، يجب طرح 10 من tempNumber للحصول على الفهرس الصحيح لـ teens
    words += teens[tempNumber - 10];
  } else if (tempNumber > 0) { // الأعداد من 1 إلى 9
    words += units[tempNumber];
  }

  return words.trim();
}