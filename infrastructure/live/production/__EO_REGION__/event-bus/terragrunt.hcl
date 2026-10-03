# The tenant's event bus, in the region events-observability runs in: an
# EventBridge rule can only target a bus in its own region. When that is the
# primary region, this unit sits next to the others.
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.modules}//event-bus"
}

inputs = {
  name        = "${include.root.locals.prefix}-events-${include.root.locals.env}"
  environment = include.root.locals.env
}
