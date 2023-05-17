$vars = @(10,20,30,40,50,60,70,80,100,200)
$dest = "192.168"
$mask = "255.255.255.0"
$hop  = "10.110.3"
foreach ($var in $vars) {
    route add -p "$dest.$var.0" mask $mask "$hop.$var"
}