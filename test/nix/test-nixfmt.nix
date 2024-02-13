{ a, bar, c ? "def" }:

let
  x = 4;
  y = "str";
in {
  inherit y;
  z = x + 2;
}
