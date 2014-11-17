/*
  mColorPicker
  Version: 1.0.0
  
  Copyright (c) 2010 Meta100 LLC.
  
  Permission is hereby granted, free of charge, to any person
  obtaining a copy of this software and associated documentation
  files (the "Software"), to deal in the Software without
  restriction, including without limitation the rights to use,
  copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the
  Software is furnished to do so, subject to the following
  conditions:
  
  The above copyright notice and this permission notice shall be
  included in all copies or substantial portions of the Software.
  
  Except as contained in this notice, the name(s) of the above 
  copyright holders shall not be used in advertising or otherwise 
  to promote the sale, use or other dealings in this Software 
  without prior written authorization.
  
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
  OTHER DEALINGS IN THE SOFTWARE.
*/

mColorPicker = {
  current_color: false,
  current_value: false,
  color: false,
  imageUrl: 'images/', //Change if you want to use local images.
  swatches: ["#ffffff","#ffff00","#00ff00","#00ffff","#0000ff","#ff00ff","#ff0000","#4c2b11","#3b3b3b","#000000"],
  colorShow: function (id, updateInput) {

    var id2 = 'icp_' + id;
        eICP = jQuery("#" + id2).offset();
  
    jQuery("#mColorPicker").css({
      'top':(eICP.top + jQuery("#" + id2).outerHeight()) + "px",
      'left':(eICP.left) + "px",
      'position':'absolute'
    }).fadeIn("fast");
  
    jQuery("#mColorPickerBg").css({
      'position':'absolute',
      'top':0,
      'left':0,
      'width':'100%',
      'height':'100%'
    }).fadeIn("fast");
  
    var def = jQuery("#" + id).val();
  
    jQuery('#colorPreview span').text(def);
    jQuery('#colorPreview').css('background', def);
    jQuery('#color').val(def);
  
    mColorPicker.current_color = jQuery('#' + id).val();
    mColorPicker.color = jQuery('#' + id).css('background-color');
    var hxs = jQuery('#mColorPicker');
  
    jQuery('#mColorPickerImg').unbind().mousemove(function(e) {
  
      var offset = jQuery('#mColorPickerImg').offset();
  
      mColorPicker.color = mColorPicker.whichColor (e.pageX - offset.left, e.pageY - offset.top);
      mColorPicker.setInputColor(id, mColorPicker.color, updateInput);
    }).bind('mouseleave', function (e) {
  
      mColorPicker.setInputColor(id, mColorPicker.current_color, updateInput);
    }).click(function(e) {
  
      mColorPicker.colorPicked(id, updateInput);
    });
  
    jQuery('#mColorPickerImgGray').unbind().mousemove(function(e) {
  
      var offset = jQuery('#mColorPickerImgGray').offset();
  
      mColorPicker.color = mColorPicker.whichColor (e.pageX - offset.left, e.pageY - offset.top + 128);
      mColorPicker.setInputColor(id, mColorPicker.color, updateInput);
    }).bind('mouseleave', function (e) {
  
      mColorPicker.setInputColor(id, mColorPicker.current_color, updateInput);
    }).click(function(e) {
  
      mColorPicker.colorPicked(id, updateInput);
    });
  
    jQuery('.pastColor').unbind().mousemove(function(e) {
  
      mColorPicker.color = mColorPicker.toRGBHex(jQuery(this).css("background-color"));
      mColorPicker.setInputColor(id, mColorPicker.color, updateInput);
    }).bind('mouseleave', function (e) {
  
      mColorPicker.setInputColor(id, mColorPicker.current_color, updateInput);
    }).click(function(e) {
  
      mColorPicker.colorPicked(id, updateInput);
    });
  
    jQuery('#mColorPickerTransparent').unbind().mouseover(function(e) {
  
      mColorPicker.color = 'transparent';
      mColorPicker.setInputColor(id, mColorPicker.color, updateInput);
    }).bind('mouseleave', function (e) {
  
      mColorPicker.setInputColor(id, mColorPicker.current_color, updateInput);
    }).click(function(e) {
  
      mColorPicker.colorPicked(id, updateInput);
    });
  
    jQuery('#mColorPickerInput').unbind().bind('keyup', function (e) {
  
      mColorPicker.color = jQuery('#mColorPickerInput').val();
      mColorPicker.setInputColor(id, mColorPicker.color, updateInput);
  
      if (e.which == 13) {
        mColorPicker.colorPicked(id, updateInput);
      }
    }).bind('blur', function (e) {
  
      mColorPicker.setInputColor(id, mColorPicker.current_color, updateInput);
    });
  
    jQuery('#mColorPickerSwatches').unbind().bind('mouseleave', function (e) {
  
      mColorPicker.setInputColor(id, mColorPicker.current_color, updateInput);
    });
  
    jQuery('#mColorPickerFooter').unbind().bind('mouseleave', function (e) {
  
      mColorPicker.setInputColor(id, mColorPicker.current_color, updateInput);
    });
  
    jQuery('#mColorPickerWrapper').unbind().bind('mouseleave', function (e) {
  
      mColorPicker.setInputColor(id, mColorPicker.current_color, updateInput);
    });
  
    jQuery('#mColorPicker').unbind().bind('mouseleave', function (e) {
  
      mColorPicker.setInputColor(id, mColorPicker.current_color, updateInput);
    });
  },
  setInputColor: function (id, color, updateInput) {
  
    var image = (color == 'transparent')? "url('" + mColorPicker.imageUrl + "grid.gif')": '',
      textColor = (color == 'transparent')? "#000000": mColorPicker.textColor(color);
  
    if (updateInput) jQuery("#icp_" + id).css({'background-color': color, 'background-image': image});
    jQuery("#" + id).val(color).css({'background-color': color, 'background-image': image, 'color' : textColor});
    jQuery("#mColorPickerInput").val(color);
  },
  textColor: function (val) {
  
    return (parseInt(val.substr(1, 2), 16) + parseInt(val.substr(3, 2), 16) + parseInt(val.substr(5, 2), 16) < 400)? 'white': 'black';
  },
  set_cookie: function (name, value, days) {
  
    var cookie_string = name + "=" + escape(value),
      expires = new Date();
      expires.setDate(expires.getDate() + days);
    cookie_string += "; expires=" + expires.toGMTString();
   
    document.cookie = cookie_string;
  },
  get_cookie: function (cookie_name) {
  
    var results = document.cookie.match ( '(^|;) ?' + cookie_name + '=([^;]*)(;|$)' );
  
    if (results) return (unescape(results[2]));
    else return null;
  },
  colorPicked: function (id, updateInput) {
  
    var swatch = [],
        i = 0;
  
    mColorPicker.current_value = mColorPicker.current_color = mColorPicker.color;
  
    jQuery("#mColorPickerImg").unbind();
    jQuery("#mColorPickerImgGray").unbind();
    jQuery(".pastColor").unbind();
    jQuery("#mColorPickerBg").hide();
    jQuery("#mColorPicker").fadeOut();
  
    if (mColorPicker.color != 'transparent') swatch[0] = mColorPicker.color;
  
    jQuery('.pastColor').each(function() {
  
      var color = mColorPicker.toRGBHex(jQuery(this).css('background-color'));

      if (color != swatch[0] && swatch.length < 10) {
  
        swatch[swatch.length] = color;
      }
  
      jQuery(this).css('background-color', swatch[i++])
    });
  
    mColorPicker.set_cookie('swatches', swatch.join(','), 365);
  },
  whichColor: function(x,y){
  
    var colorR = colorG = colorB = 256;
    
    if (x < 32) {
  
      colorG = x * 8;
      colorB = 1;
    } else if (x < 64) {
  
      colorR = 256 - (x - 32 ) * 8;
      colorB = 1;
    } else if (x < 96) {
  
      colorR = 1;
      colorB = (x - 64) * 8;
    } else if (x < 128) {
  
      colorR = 1;
      colorG = 256 - (x - 96) * 8;
    } else if (x < 160) {
  
      colorR = (x - 128) * 8;
      colorG = 1;
    } else {
  
      colorG = 1;
      colorB = 256 - (x - 160) * 8;
    }
  
    if (y < 64) {
  
      colorR = colorR + (256 - colorR) * (64 - y) / 64;
      colorG = colorG + (256 - colorG) * (64 - y) / 64;
      colorB = colorB + (256 - colorB) * (64 - y) / 64;
    } else if (y <= 128) {
  
      colorR = colorR - colorR * (y - 64) / 64;
      colorG = colorG - colorG * (y - 64) / 64;
      colorB = colorB - colorB * (y - 64) / 64;
    } else if (y > 128) {
  
      colorR = 256 - ( x / 192 * 256 );
      colorG = 256 - ( x / 192 * 256 );
      colorB = 256 - ( x / 192 * 256 );
    }
    
    colorR = parseInt(colorR);
    colorG = parseInt(colorG);
    colorB = parseInt(colorB);
    
    if (colorR >= 256) colorR = 255;
    if (colorG >= 256) colorG = 255;
    if (colorB >= 256) colorB = 255;
    
    colorR = colorR.toString(16);
    colorG = colorG.toString(16);
    colorB = colorB.toString(16);
    
    if (colorR.length < 2) colorR = 0 + colorR;
    if (colorG.length < 2) colorG = 0 + colorG;
    if (colorB.length < 2) colorB = 0 + colorB;
    
    return "#" + colorR + colorG + colorB;
  },
  toRGBHex: function (num) {
  
    if (num.indexOf('#') > -1) return num;

    var hexArray = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"],
        decToHex = "#",
        code1 = 0;
  
    num = num.replace(/[^0-9,]/g, '').split(",");

    for (var n = 0; n < num.length; n++) {

      code1 = Math.floor(num[n] / 16);
      decToHex += hexArray[code1] + hexArray[num[n] - code1 * 16];
    }
  
    return decToHex;
  },
  main: function() {
  
    jQuery('input').filter(function(index) {
  
      return this.getAttribute("type") == 'color';
    }).each(function (i) {
  
      if (i == 0) {
  
        jQuery(document.createElement("div")).attr(
          "id","mColorPicker"
        ).css(
          'display','none'
        ).html(
          '<div id="mColorPickerWrapper"><div id="mColorPickerImg"></div><div id="mColorPickerImgGray"></div><div id="mColorPickerSwatches"><div id="cell0" class="pastColor">&nbsp;</div><div id="cell1" class="pastColor noLeftBorder">&nbsp;</div><div id="cell2" class="pastColor noLeftBorder">&nbsp;</div><div id="cell3" class="pastColor noLeftBorder">&nbsp;</div><div id="cell4" class="pastColor noLeftBorder">&nbsp;</div><div id="cell5" class="pastColor noLeftBorder">&nbsp;</div><div id="cell6" class="pastColor noLeftBorder">&nbsp;</div><div id="cell7" class="pastColor noLeftBorder">&nbsp;</div><div id="cell8" class="pastColor noLeftBorder">&nbsp;</div><div id="cell9" class="pastColor noLeftBorder">&nbsp;</div><div class="clear"></div></div><div id="mColorPickerFooter"><input type="text" size="8" id="mColorPickerInput"/><span id="mColorPickerTransparent">transparent</span></div></div>'
        ).appendTo("body");
  
        jQuery(document.createElement("div")).attr("id","mColorPickerBg").click(function() {
  
          jQuery("#mColorPickerBg").hide();
          jQuery("#mColorPicker").fadeOut()
        }).appendTo("body");
  
        jQuery('table.pickerTable td').css({
          'width':'12px',
          'height':'14px',
          'border':'1px solid #000',
          'cursor':'pointer'
        });
  
        jQuery('#mColorPicker table.pickerTable').css({
          'border-collapse':'collapse'
        });
  
        jQuery('#mColorPicker').css({
          'border':'1px solid #ccc',
          'background':'#333',
          'color':'#fff',
          'z-index':999998,
          'width':'194px',
          'height':'184px',
          'font-size':'12px',
          'font-family':'times'
        });
  
        jQuery('.pastColor').css({
          'height':'18px',
          'width':'18px',
          'border':'1px solid #000',
          'float':'left'
        });
    
        jQuery('#colorPreview').css({
          'height':'50px'
        });
    
        jQuery('.noLeftBorder').css({
          'border-left':'0'
        });
    
        jQuery('.clear').css({
          'clear':'both'
        });
    
        jQuery('#mColorPickerWrapper').css({
          'position':'relative',
          'border':'solid 1px gray',
          'background-color':'white',
          'z-index':'999999'
        });
        
        jQuery('#mColorPickerImg').css({
          'height':'128px',
          'width':'192px',
          'border':'0',
          'cursor':'crosshair',
          'background-image':"url('" + mColorPicker.imageUrl + "colorpicker.png')"
        });
        
        jQuery('#mColorPickerImgGray').css({
          'height':'8px',
          'width':'192px',
          'border':'0',
          'cursor':'crosshair',
          'background-image':"url('" + mColorPicker.imageUrl + "graybar.jpg')"
        });
        
        jQuery('#mColorPickerInput').css({
          'border':'solid 1px gray',
          'font-size':'12pt',
          'margin':'1px'
        });
        
        jQuery('#mColorPickerImgGrid').css({
          'border':'0',
          'height':'20px',
          'width':'20px',
          'vertical-align':'text-bottom'
        });
        
        jQuery('#mColorPickerSwatches').css({
          'background-color':'#000'
        });
        
        jQuery('#mColorPickerFooter').css({
          'background-image':"url('" + mColorPicker.imageUrl + "grid.gif')"
        });
        
        jQuery('#mColorPickerTransparent').css({
          'font-size':' 18px',
          'color':'#000',
          'padding-left':' 4px',
          'cursor':' pointer',
          'overflow': 'hidden'
        });
      }
  
      var id = jQuery(this).attr('id'),
          currentTime = new Date(),
          updateInput = false;
  
      if (id == '') id = jQuery(this).attr('name');
      if (id == '') id = 'color_' + currentTime.getTime();
  
      jQuery(this).attr('id', id);
  
      if (jQuery(this).attr('text') == 'hidden') {
  
        var color = jQuery(this).val(),
            width = (jQuery(this).width() > 0)? jQuery(this).width(): parseInt(jQuery(this).css('width'));
            height = (jQuery(this).height())? jQuery(this).height(): parseInt(jQuery(this).css('height'));
            flt = jQuery(this).css('float'),
            image = (color == 'transparent')? "url('" + mColorPicker.imageUrl + "/grid.gif')": '',
            textColor = (color == 'transparent')? "#000000": mColorPicker.textColor(color),
            colorPicker = '';
    
        jQuery('body').append('<span id="color_work_area"></span>');
        jQuery('span#color_work_area').append(jQuery(this).clone(true));
        colorPicker = jQuery('span#color_work_area').html().replace(/type=[^a-z]*color[^a-z]*/gi, 'type="hidden"');
        jQuery('span#color_work_area').html('').remove();
        jQuery(this).after(
          '<span style="cursor:pointer;border:1px solid black;float:' + flt + ';width:' + width + 'px;height:' + height + 'px;" id="icp_' + id + '">&nbsp;</span>'
        ).after(colorPicker).remove();   
  
        jQuery('#icp_' + id).css({
          'background-color': color,
          'background-image': image,
          'display': 'inline-block',
          'color' : textColor
        });
  
        updateInput = true;
      } else {
  
        var color = jQuery(this).val(),
            id = jQuery(this).attr('id'),
            image = (color == 'transparent')? "url('" + mColorPicker.imageUrl + "/grid.gif')": '',
            textColor = (color == 'transparent')? "#000000": mColorPicker.textColor(color),
            colorPicker = '';
    
        jQuery('body').append('<span id="color_work_area"></span>');
        jQuery('span#color_work_area').append(jQuery(this).clone(true));
        colorPicker = jQuery('span#color_work_area').html().replace(/type=[^a-z]*color[^a-z]*/gi, 'type="text"');
        jQuery('span#color_work_area').html('').remove();
        jQuery(this).after(colorPicker).remove();   

        jQuery('#' + id).css({
          'background-color': color,
          'background-image': image,
          'color' : textColor
        }).after(
          '<span style="cursor:pointer;" id="icp_' + id + '"><img src="' + mColorPicker.imageUrl + 'color.png" style="border:0;margin:0 0 0 3px" align="absmiddle"></span>'
        );
      }
  
      jQuery('#icp_' + id).bind('click', function () {
  
        mColorPicker.colorShow(id, updateInput);
      });
  
      var swatch = mColorPicker.get_cookie('swatches'),
      i = 0;
  
      if (swatch == null) swatch = mColorPicker.swatches;
      else swatch = swatch.split(',');
  
      jQuery(".pastColor").each(function() {
  
        jQuery(this).css('background-color', swatch[i++]);
      });
    });
  }
};

jQuery(document).ready(function () {

  mColorPicker.main();
});