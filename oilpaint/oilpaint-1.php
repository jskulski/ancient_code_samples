<html>
<head>
  <title>Oilpaint #1</title>
  <script type="text/javascript" src="jquery.js"></script>
  <script type="text/javascript" src="oilpaint-1.js"></script>
  <style type="text/css">
#moving-box { 
  border: 1px solid #000;   
  background-color: #000;
  left: 1px;
  top:40px;
  position: absolute;
  }

#art-box { 
  position:absolute;
  display: none;
  background-image: url(js_art3.png);
margin: 10px;
  width: 100px;
  height: 144px;
  }

#click-box { 
position: absolute;
top: 80px;
right: 30px;
  }

#click-box-too { 
position: absolute;
top: 110px;
right: 30px;
  }

.square { 
  width: 10px;
  height: 10px;
  border: 1px dashed #000;
  float: left;
  }

.row { 
  clear: both;
  position:absolute;
  left:0px;
  top:50px;
  }

.boxes-border { 
  padding: 3px;
  border: 1px dashed #000;
  }

h3 {
  color: red;
  text-align: right; 
  font-size: 20pt
  }
  </style>
</head>
<body>
<h3 class="title">oilpainting-1</h3>

<div id="art-box">&nbsp;</div>
<div id="click-box">c l i c k p l e a s e</div>
<div id="click-box-too">n o , o n t h e <span class="boxes-border">boxes</span></div>
<div id="moving-box" class="square"></div>
<?php

$num = 102;

print "<div class='row'>";
for ($i = 0; $i<$num; $i++) { 
  print "<div num='$i' class='square square-$i floor'>";
  print "</div>";
}
print "</div>";

?>


</body>
</html>
