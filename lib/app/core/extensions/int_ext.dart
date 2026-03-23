extension IntExt on int {
  String toTime() => this < 10 ? '0$this' : toString();
}
