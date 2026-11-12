import 'package:flutter_test/flutter_test.dart';
import 'package:nihaoki/services/ai_tutor_service.dart';

void main() {
  group('Riwayat percakapan AI', () {
    test('Mengirim hanya pasangan pertanyaan dan jawaban yang lengkap', () {
      expect(
        buildAiHistory([
          {'role': 'user', 'text': 'Pertanyaan terjawab'},
          {'role': 'model', 'text': 'Jawaban'},
          {'role': 'user', 'text': 'Permintaan yang gagal'},
        ]),
        [
          {'role': 'user', 'text': 'Pertanyaan terjawab'},
          {'role': 'model', 'text': 'Jawaban'},
        ],
      );
    });

    test(
      'Membuang pertanyaan yatim sebelumnya dan membatasi ke empat giliran',
      () {
        final history = <Map<String, String>>[
          {'role': 'user', 'text': 'Pertanyaan tanpa jawaban'},
        ];
        for (var index = 0; index < 5; index++) {
          history
            ..add({'role': 'user', 'text': 'Pertanyaan $index'})
            ..add({'role': 'model', 'text': 'Jawaban $index'});
        }

        expect(buildAiHistory(history), hasLength(8));
        expect(buildAiHistory(history).first['text'], 'Pertanyaan 1');
        expect(buildAiHistory(history).last['text'], 'Jawaban 4');
      },
    );
  });

  group('Pembersihan format jawaban AI', () {
    test('Menghapus pembatas rumus dolar tanpa menghapus teks rumus', () {
      expect(cleanAiAnswer(r'Jawaban: $1 + 1 = 2$'), 'Jawaban: 1 + 1 = 2');
      expect(cleanAiAnswer(r'$$x^2 + 1$$'), 'x^2 + 1');
      expect(cleanAiAnswer(r'\(a + b\)'), 'a + b');
    });

    test('Mempertahankan simbol dolar harga yang tidak berpasangan', () {
      expect(cleanAiAnswer(r'Harga $5'), r'Harga $5');
    });
  });
}
