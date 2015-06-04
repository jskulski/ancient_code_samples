$(document).ready(function() { 

  var d = 5;
  var g = .1;
  var fall = 10;
  var move = 6.5;
  var boxmove = .5;
  var leftcount = 10;
  var box = $('#moving-box');
  var nextbox = 1;
  var falling = false;

  //animate back forthness
  setInterval(function() { 
      if (fall > 100) { 
        box.css('opacity', 0);
        $('#art-box')
          .animate({'width': "500px"}, 500)
          .animate({'height': "500px"}, 500);
        return;
      }
      if (leftcount > 1000) { 
        move = -1*move;
        boxmove = -1;
      }
      if (leftcount < 10) { 
        move = -1*move;
        boxmove = 1;
      }

      if (falling || $('.square-'+nextbox).css('opacity') == 0) { 
        falling = true;
        fall += fall * g;
        box.animate(
          { 
            "left":"+="+move+"px",
            "top": "+="+fall+"px",
          }, 100);

        $('#art-box').css('left', leftcount+"px").fadeIn('slow');
      } else { 
        box.animate({"left": "+="+move+"px"}, 100);
        leftcount += move;
      }

      nextbox = nextbox + boxmove;
    },
    100
  );

  $('.floor').click(
    function() { 
      var num = $(this).attr('num');
      $(this)
        .unbind('click')
        .css('border-color', 'red');
      for (var i = -5; i <= d; i++) { 
        var next = parseInt(num) + i;
        $('.square-'+next)
          .unbind('click')
          .css('background-color', 'FF0000')
          .animate(
            { 
              opacity: "0%",
            }, 1500);
      }
    });

});
