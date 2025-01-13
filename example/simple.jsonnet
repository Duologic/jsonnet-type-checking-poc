local validate = import '../main.libsonnet';

local func(arg) =
  assert validate.checkParameters({
    arg: std.isString(arg),
  });
  {/* do something here */ };

func(false)
