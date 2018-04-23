# rotate/flip a quadrant appropriately
rot = (n, p, r)->
    if r.y == 0
        if r.x == 1
            p.x = n-1 - p.x;
            p.y = n-1 - p.y;
        [p.x, p.y] = [p.y, p.x] 
    p
    
# convert (x,y) to d
xy2d = (n, p)->
    d = 0
    r = {}
    s = n>>1
    while s>0
        r.x = (p.x & s) > 0;
        r.y = (p.y & s) > 0;
        d += s * s * ((3 * r.x) ^ r.y);
        p = rot(s, p, r);
        s = s>>1
        
    d
 
#convert d to (x,y)
d2xy = (n, d)->
    t = d
    p = {x:0, y:0}
    r = {}
    s = 1
    while s < n
        r.x = 1 & (t>>1)
        r.y = 1 & (t ^ r.x)
        p = rot(s, p, r)
        p.x += s * r.x
        p.y += s * r.y
        t = t>>2
        s = s<<1
    p


# >>>0 Трюк для перевода в uint32
cidr2range = (cidr)->
    [ip, mask] = cidr.split "/"
    console.log cidr, ip, mask
    mask = parseInt(mask, 10)  >>>0
    mask = (-1) << (32 - mask) >>>0
    ip = ip.split(".").map (a)->parseInt a, 10
    ip = ip[0]<<24 | ip[1]<<16 | ip[2]<<8 | ip[3] >>>0

    start = ip    &	 mask >>> 0
    end   = start | ~mask >>> 0
    start: start, end: end


ip2hex = (ip)-> "00000000#{ip.toString(16)}"[-8..]
ip2dec = (ip)->
    ip = ip2hex ip
    ip = ("#{parseInt(ip[i*2..i*2+1],16)}" for i in [0..3]).join "."


get_file = (file, cb)->
    req = new XMLHttpRequest();
    req.open 'GET', file
    req.onloadend = ()->
        console.log req
        cb req.responseText
    req.send();


class MaskCanvas

    constructor:(@cvs, @size=0)->
        @ctx = @cvs.getContext "2d"
        @h = @w = @cvs.height = @cvs.width = 1<<(8+@size)
        @b = cvs.getBoundingClientRect()
        @cvs.addEventListener "mousemove", @mousemove

    plot_cidrs: (cidrs, color) =>
        id = @ctx.getImageData 0, 0, @w, @h
        d = id.data
        for cidr in cidrs 
            range = cidr2range cidr
            console.log ip2hex(range.start), ip2hex(range.end)

            range.start = range.start >>2*(8-@size)>>>0
            range.end   = range.end   >>2*(8-@size)>>>0
            console.log range.start, range.end

            for l in [range.start..range.end]
                p = d2xy(@h,l)
                k1 = color.a/255.0
                k2 = 1.0 - k1
                d[(p.x+p.y*@w)*4+0]*=k2; d[(p.x+p.y*@w)*4+0] +=color.r*k1
                d[(p.x+p.y*@w)*4+1]*=k2; d[(p.x+p.y*@w)*4+1] +=color.g*k1
                d[(p.x+p.y*@w)*4+2]*=k2; d[(p.x+p.y*@w)*4+2] +=color.b*k1
                d[(p.x+p.y*@w)*4+3] = 255
        @ctx.putImageData id, 0, 0
        
    clear: =>
        @ctx.fillStyle = "#000"
        @ctx.fillRect 0, 0, @w, @h

    mousemove: (e)=>
        x = e.clientX-@b.left
        y = e.clientY-@b.top
        ip = xy2d @h, {x:x, y:y}
        ip = ip << (8-@size)*2 >>>0
        cursor_ip.innerHTML = """#{ip2hex ip}\n#{ip2dec ip}"""


hex2color = (hex)->
    c = parseInt hex, 16
    r: (c>>24)&0xFF
    g: (c>>16)&0xFF
    b: (c>> 8)&0xFF
    a:  c     &0xFF
    

draw = ()->
    data = cidrs.innerHTML.split /\n/
    data = data.map (l)-> l.split(/\s*#/)[0]
    color = hex2color colors_sel.options[colors_sel.selectedIndex].value[1..]
    mask_cvs.plot_cidrs data, color


cidrs_sel  = document.getElementById "cidrs_sel"
cidrs      = document.getElementById "cidrs"
cvs        = document.getElementById "cvs"
colors_sel = document.getElementById "colors_sel"
cursor_ip  = document.getElementById "ip"

mask_cvs = new MaskCanvas(cvs, 2)

cidrs_change = ->
    value = cidrs_sel.options[cidrs_sel.selectedIndex].value
    await get_file value, defer text
    cidrs.innerHTML = text
cidrs_sel.addEventListener "change", cidrs_change
cidrs_change()

draw_btn = document.getElementById "draw"
draw_btn.addEventListener "click",draw
clear_btn = document.getElementById "clear"
clear_btn.addEventListener "click", -> mask_cvs.clear()

cidrs.addEventListener "keydown", (e)->
    draw() if e.code is "Enter" and e.ctrlKey


console.log "start"

