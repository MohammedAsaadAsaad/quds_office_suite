import 'dart:io';
import 'package:quds_office_engine/pdf_file.dart';

void dump(PdfOutlineNode n, [int d=0]) {
  print('${'  '*d}"${n.title}" page=${n.pageIndex} destY=${n.destY} kids=${n.children.length}');
  for (final c in n.children) dump(c, d+1);
}

void main() {
  final f = PdfFile.open(File('/home/mohammed/Desktop/al_tahreer_profile.pdf').readAsBytesSync());
  final o = f.outline;
  print('outline null? ${o==null}');
  if (o!=null) dump(o);
}
