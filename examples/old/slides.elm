titleWrite = "Write your program"

main = <div id="app">
<div class="slides" id="slides" contenteditable="true">
  @fullscreenbutton
  <slide ignore-position="current">
    <h1 class="center1">Sketch-n-Sketch 2.0</h1>
    @Html.forceRefresh<|
    <h2 class="center2">Ravi Chugh and Mikaël Mayer</h2>
  </slide>
  <slide ignore-position="future">
    <h1>@titleWrite</h1>
    Use standard Elm-like constructs
    <ul>
      <li>@(minieval "let x = \"Hello \" in x + x + \"world\"")</li>
      <li>@(minieval "map (\\x -> x + 5) [1, 2, 4]")</li>
    </ul>
  </slide>
  <slide ignore-position="future">
    <h1>@titleWrite</h1>
    You can use HTML syntax, and it's <i>interpolated</i>.@Html.forceRefresh<|<ul>
      <li>@(minievalx "let f x = <b title=\"I said \"+x>@x world</b> in f 'Hello'")</li>
      <li>@(minievalx "let f n = n + \" team. \" in map (\\x -> <i style=\"\"\"color:@x\"\"\">@f(x)</i>) [\"red\", \"yellow\", 'blue']")</li>
    </ul>
  </slide>
  <slide ignore-position="future">
    <h1>Translate slides</h1><div>By applying a single function, you can start translating slides to different languages right away!</div>
  </slide>
</div>
<style>
slide {
  color: black;
  background: none;
}
.slides {
  background: lightblue;
  font-family: "Roboto", "Avenir", sans-serif;
}
.code {
  font-family: "Consolas", monospace;
}
</style>
@Html.forceRefresh<|<script>
var container = document.querySelector("#slides");
if(container !== null) {
  container.onscroll = function () {
    container.scrollLeft = 0;
  }
}
</script>
@Html.forceRefresh<|<script>
var container = document.querySelector("#slides");
if(typeof keyDown != "undefined" && container !== null) {
  container.removeEventListener("keydown", keyDown, false);
}

keyDown = function (e) {
  var keyCode = e.keyCode;
  var current = document.querySelector("slide[ignore-position=current]");
  if(keyCode == 39 ) { // Right
    var next = current.nextElementSibling;
    while(next != null && next.tagName != "SLIDE"){
      next = next.nextElementSibling
    }
    if(next != null) {
      next.setAttribute("ignore-position","current");
      current.setAttribute("ignore-position", "past");
    }
    return false;
  } else if(keyCode == 37) { // Left
    var prev = current.previousElementSibling;
    while(prev != null && prev.tagName != "SLIDE"){
      prev = prev.previousElementSibling
    }
    if(prev != null) {
      prev.setAttribute("ignore-position","current");
      current.setAttribute("ignore-position", "future");
    }
    return false;
  }
  return true;
}
if(container !== null) {
  container.addEventListener("keydown", keyDown, false);
}
</script>
@let center translateY = """{
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%) translateY(@translateY);
  width: 100%;
  text-align: center;
}""" in <style>
#fullscreenbutton {
  z-index: 1001;
  position: absolute;
  opacity: 0.2;
}
#fullscreenbutton:hover {
  opacity: 1;
}
.slides {
  display: block;
  width: 100%;
  padding-bottom: 56.25%; /* 16:9 */
  position: relative;
  overflow: hidden;
}
slide {
  position: absolute;
  top: 0; bottom: 0; left: 0;
  width: 100%;
  font-size: 1em;
  padding: 20px;
  box-sizing: border-box;
}
[ignore-position="current"] {
  left: 0;
  transition: @delay;
}
[ignore-position="future"] {
  left: 100%;
  width: 100%;
  transition: @delay;
}
[ignore-position="past"] {
  left: -100%;
  width: 100%;
  transition: @delay;
}
.slides.fullscreen {
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  z-index: 1000;
}
slide h1, slide h2 {
  margin-top: 0px;
}
.center1 @center("-1em")
.center2 @center("0em")
</style>
</div>

delay = "0.5s"

displayError msg = <span style="color:red;white-space:pre;">@msg</span>

minieval x =
  <span class="code">@x<div><b>⇨ </b
      >@(case __evaluate__ (__CurrentEnv__) x of
    Ok x -> toString x 
    Err msg -> displayError msg)</div></span>

minievalx x =
  <span class="code">@x<br><b>⇨ </b>@(case __evaluate__ (__CurrentEnv__) x of
    Ok x -> x
    Err msg -> displayError msg
  )</span>


fullscreenbutton = [
  <button id="fullscreenbutton" onclick="""
if(typeof isFullScreen == "undefined")
  isFullScreen = false;
isFullScreen = !isFullScreen;
var d = document.getElementById("fullscreenstyle")
if(isFullScreen) {
  d.innerHTML = `<style>
body {
  background: white;
}
body * {
  visibility: hidden;
}
#outputCanvas {
  height: auto !important;
  overflow: visible;
}
#app {
  position: absolute;
  height: auto;
  width: 100%;
  overflow: visible;
  width: 100vw;
  font-size: 2em;
}
#app, #app * {
  visibility: visible;
}
.code-panel {
  display: none;
}
.output-panel {
  left: 0 !important;
  top: 0 !important;
  right: 0 !important;
  bottom: 0 !important;
}
</style>`
} else {
  d.innerHTML = ""
}""">Fullscreen</button>,
<div><transient id="fullscreenstyle"></transient></div>]
