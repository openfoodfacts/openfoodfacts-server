
		var world;
		var bodies = [];	// instances of b2Body (from Box2D)
		var actors = [];	// instances of Bitmap (from IvanK)
		var cubes = [];
		var ncubes = 0; // fallen cubes
		var min_height = 0;
		var max = 75;
		var ncubes2 = 0; // total cubes
		var show_answer = 0;
	
		var tries = 5;
		var product = 0;
		
		var targetheight = 750;
		var height = 750;
	
		
		function update_progress_bar() {
		
			
			
			var progressmsg = '';
			
			if (product == 0) {
				progressmsg = 'Evaluate the quantity of sugar of ' + tries + ' products to see your score.';
			}
			else if (product < tries - 1) {
				progressmsg = 'Evaluate ' + (tries - product) + ' more products to see your score.';
			}
			else if (product == tries - 1) {
				progressmsg = 'Only one product to evaluate to see your score.';
			}
			
			$( "#progressmsg" ).html(progressmsg);

			if (product > 0) {
				$('#progressbar').height(30);
				$( "#progressbar" ).progressbar({ value : product , max: tries });		
			}
	
			
		
		}
		
		$(function() {
			Start();
			$('body').nivoZoom();
		});
		
		function Start() 
		{	
			var windowheight = $(window).height();
			


			if (windowheight < targetheight + 45) {

				height = windowheight - 45;
								
				if (height < 560) {
					height = 560;
				}
			}	

			if (windowheight < 875) {
				$("#mice").css("padding", "0px");
				$("#mice").css("width", "450px");
				$("#cubes").css("font-size", "30px");
				$("#cubes").css("display", "inline")
				$("#cubes2").css("display", "inline")
				$("#your_answer").css("display", "inline")			
			}
				
			if (height < 750) {				
				$("#c").attr("height", height);
				$("#sugar_cubes").css("height", height);
				$("#main").css("height", height);
				$("#title").css("font-size", "16px");
				//$("#answer").css("font-size","0.8em");
				//$("#info").css("font-size","0.8em");
			}
			
			if (height < 640) {
				$("#sharebuttons").hide();
				$("#play").hide();				
			}
		
			if ($.sessionStorage.getItem('product')) {
				product = parseInt($.sessionStorage.getItem('product'));
				if (product >= tries) {
					product = 0;
				}
			}
			
			update_progress_bar();
			$("#help").show();
		
			
			var renderer = PIXI.autoDetectRenderer(450, height,document.getElementById("c"));
			document.getElementById("sugar_cubes").appendChild(renderer.view);
			
			var interactive = true;
			var stage = new PIXI.Stage("0x0000ff", interactive);
	
			//stage.addEventListener(Event.ENTER_FRAME, onEF);
			
			// background
			
			var bgTexture = new PIXI.Texture.fromImage("sucres_bgr.png");
			var bg = new PIXI.Sprite(bgTexture);

			bg.position.x = 0;
			bg.position.y = 0;

			// bg.scale.x = bg.scale.y = 1;

			stage.addChild(bg);
			
			// icons
			
			
			var alienContainer = new PIXI.DisplayObjectContainer();
			alienContainer.position.x = 0;
			alienContainer.position.y = 0;
			stage.addChild(alienContainer);			
			
			
			function add_button(x,y,texture) {
			
				var textureButton = new PIXI.Texture.fromImage(texture + ".png");
				var textureButtonOver = new PIXI.Texture.fromImage(texture + "h.png");
				var textureButtonDown = new PIXI.Texture.fromImage(texture + "c.png");
				var sprite = new PIXI.Sprite(textureButton);
				sprite.position.x = x;
				sprite.position.y = y;
				sprite.setInteractive(true);
				stage.addChild(sprite);
				sprite.mousedown = sprite.touchstart = function(data){
					this.isdown = true;
					this.setTexture(textureButtonDown);
					this.alpha = 1;
				}
				sprite.mouseup = sprite.touchend = function(data){
					this.isdown = false;
					if(this.isOver)
					{
						this.setTexture(textureButtonOver);
					}
					else
					{
						this.setTexture(textureButton);
					}
				}
				sprite.mouseover = function(data){
					this.isOver = true;
					if(this.isdown)return
					this.setTexture(textureButtonOver)
				}
				sprite.mouseout = function(data){
					this.isOver = false;
					if(this.isdown)return
					this.setTexture(textureButton)
				}			
				
				return sprite;			
			}
			
			
			var sm1 = add_button(10,10,"sugar_minus_1");		
			sm1.click = sm1.tap = function(mouseData){
				remove_sugar(1);
			}
			
			var sm2 = add_button(10,120,"sugar_minus_5");	
			sm2.click = sm2.tap = function(mouseData){
				remove_sugar(5);
			}			
			
			var sp1 = add_button(340,10,"sugar_plus_1");
			sp1.click = sp1.tap = function(mouseData){
				add_sugar(1);
			}
			
			var sp2 = add_button(340,120,"sugar_plus_5");		
			sp2.click = sp2.tap = function(mouseData){
				add_sugar(5);
			}			

			var ok = add_button(340,230,"sugar_ok");		
			ok.click = ok.tap = function(mouseData){
				ok.position.y = -340;
				sp1.position.y = -340;
				sp2.position.y = -340;
				sm1.position.y = -340;
				sm2.position.y = -340;
				
				
				
				if (small > ncubes2) {
					roux = 1;
					add_sugar(small - ncubes2);
				}
				else {
					remove_sugar(ncubes2 - small);
				}
				
				$('#info').fadeOut("slow", function(){
				  show_answer = 1;
				});			
				

				
				var points = 10 - Math.floor(Math.abs(ncubes - small_f) / small_f * 10);

				if (points < (10 - Math.floor(Math.abs(ncubes - small_f)))) {
					points = 10 - Math.floor(Math.abs(ncubes - small_f));
				}
				
				if (points < 0) {
					points = 0;
				}				
				
				product++;
				
				document.getElementById('your_answer').innerHTML = "(your answer: " + ncubes + " - " + points + "/10 points)";
				
				$.sessionStorage.setItem('product_answer_' + product, ncubes);
				$.sessionStorage.setItem('product_actual_' + product, small_f);
				$.sessionStorage.setItem('product_points_' + product, points);

				
				$.post("/cgi/sugar_check.pl", { product: product, code: code, name: name, actual : small_f, answer: ncubes, points: points });
				
			}
			

			
				
			
			//requestAnimationFrame(animate);			
			
			var	b2Vec2	= Box2D.Common.Math.b2Vec2,
					b2AABB = Box2D.Collision.b2AABB,
					b2MouseJointDef =  Box2D.Dynamics.Joints.b2MouseJointDef,
					b2BodyDef	= Box2D.Dynamics.b2BodyDef,
					b2Body		= Box2D.Dynamics.b2Body,
					b2FixtureDef	= Box2D.Dynamics.b2FixtureDef,
					b2World		= Box2D.Dynamics.b2World,
					b2PolygonShape	= Box2D.Collision.Shapes.b2PolygonShape;


            
					
			world = new b2World(new b2Vec2(0, 30),  true);
			
			// I decided that 1 meter = 100 pixels
			
			var bxFixDef	= new b2FixtureDef();	// box  fixture definition
			bxFixDef.shape	= new b2PolygonShape();

			
			var bodyDef = new b2BodyDef();
			bodyDef.type = b2Body.b2_staticBody;
			
			// create ground
			bxFixDef.shape.SetAsBox(10, 1);
			bodyDef.position.Set(9, height/100 + 1);
			world.CreateBody(bodyDef).CreateFixture(bxFixDef);
			
			bxFixDef.shape.SetAsBox(1, 100);
			// left wall
			bodyDef.position.Set(-1, 3);
			world.CreateBody(bodyDef).CreateFixture(bxFixDef);
			// right wall
			bodyDef.position.Set(450/100 + 1, 3);
			world.CreateBody(bodyDef).CreateFixture(bxFixDef);
			
			
			
			bxFixDef.density = 1;
			bxFixDef.friction = 0.5;
			bxFixDef.restitution = 0.1;			
			
			
			var bxTexture = new PIXI.Texture.fromImage("sucre-blanc.60x52.png");
			var bxTexture2 = new PIXI.Texture.fromImage("sucre-roux.60x52.png");

			var roux = 0;
			
			// let's add 25 boxes and 25 balls!
			function add_sugar(nb) {
			
				bodyDef.type = b2Body.b2_dynamicBody;
				for(var i = 0; i < nb; i++)
				{
					
					var hw = 0.30 * 0.95;
					var hh = 0.26 * 0.95;
					
					
					bxFixDef.shape.SetAsBox(hw, hh);
					bodyDef.position.Set(Math.random()*0.5+2, -5 + Math.random()*5 - i);
					if (small > 0) {
						bodyDef.angle = Math.random()*3.14*2;
					}
					bodyDef.linearDamping = 0.1;
					bodyDef.angularDamping = 0.1;
					bodyDef.allowSleep = true;
					bodyDef.awake = true;

					
					var body = world.CreateBody(bodyDef);
					body.CreateFixture(bxFixDef);	// box
					
					bodies.push(body);
					
					
					var bx;
					if (roux < 1) {
						bx = new PIXI.Sprite(bxTexture);
					}
					else {
						bx = new PIXI.Sprite(bxTexture2);
					}
					bx.setInteractive(true);

					bx.anchor.x = 0.5;
					bx.anchor.y = 0.5;

					// bx.scale.x = bx.scale.y = 1;

					
					actors.push(bx);
					alienContainer.addChild(bx);
					
				}
				
				ncubes2 += nb;
				
				$("#help").fadeOut();
			}
		
		
			function remove_sugar(nb) {
			
				for(var i = 0; i < nb; i++)
				{
					
					body = bodies.pop();
					if (body) {
						world.DestroyBody(body);
					}
					bx = actors.pop();
					if (bx) {
						alienContainer.removeChild(bx);							
					}
					
				}
				
				ncubes2 -= nb;
			
			}		
		
		
			if (small < 0) {
			
				ok.position.y = -340;
				sp1.position.y = -340;
				sp2.position.y = -340;
				sm1.position.y = -340;
				sm2.position.y = -340;				
			
					var play = add_button(54, 100,"sugar_play");		
					play.click = play.tap = function(mouseData){
						window.location = "http://howmuchsugar.in/cgi/sugar_random.pl";
					}	
				add_sugar(6);
			
			}		
		
         //mouse
         
         var mouseX, mouseY, mousePVec, isMouseDown, selectedBody, mouseJoint;
         var canvasPosition = getElementPosition(document.getElementById("sugar_cubes"));
         
         document.addEventListener("mousedown", function(e) {
            isMouseDown = true;
            handleMouseMove(e);
            document.addEventListener("mousemove", handleMouseMove, true);
         }, true);
         
         document.addEventListener("mouseup", function(e) {
            document.removeEventListener("mousemove", handleMouseMove, true);
            isMouseDown = false;
            mouseX = undefined;
            mouseY = undefined;
         }, true);
         
         function handleMouseMove(e) {
			canvasPosition = getElementPosition(document.getElementById("sugar_cubes"));
            mouseX = (e.clientX - canvasPosition.x) / 100;
            mouseY = (e.clientY - canvasPosition.y + $(window).scrollTop()) / 100;
			//alert( $(window).scrollTop());
         };
         
         function getBodyAtMouse() {
            mousePVec = new b2Vec2(mouseX, mouseY);
            var aabb = new b2AABB();
            aabb.lowerBound.Set(mouseX - 0.001, mouseY - 0.001);
            aabb.upperBound.Set(mouseX + 0.001, mouseY + 0.001);
            
            // Query the world for overlapping shapes.

            selectedBody = null;
            world.QueryAABB(getBodyCB, aabb);
            return selectedBody;
         }

         function getBodyCB(fixture) {
            if(fixture.GetBody().GetType() != b2Body.b2_staticBody) {
               if(fixture.GetShape().TestPoint(fixture.GetBody().GetTransform(), mousePVec)) {
                  selectedBody = fixture.GetBody();
                  return false;
               }
            }
            return true;
         }		
		
		
		var z = 0;
		
		function animate() 
		{
			z++;

            if(isMouseDown && (!mouseJoint)) {
               var body = getBodyAtMouse();
               if(body) {
                  var md = new b2MouseJointDef();
                  md.bodyA = world.GetGroundBody();
                  md.bodyB = body;
                  md.target.Set(mouseX, mouseY);
                  md.collideConnected = true;
                  md.maxForce = 300.0 * body.GetMass();
                  mouseJoint = world.CreateJoint(md);
                  body.SetAwake(true);
               }
            }
            
            if(mouseJoint) {
               if(isMouseDown) {
                  mouseJoint.SetTarget(new b2Vec2(mouseX, mouseY));
               } else {
                  world.DestroyJoint(mouseJoint);
                  mouseJoint = null;
               }
            }		
		
			world.Step(1 / 60,  8,  3);
			world.ClearForces();
			
			ncubes = 0;
			
			for(var i=0; i<actors.length; i++)
			{
				var body  = bodies[i];
				var actor = actors[i];
				var p = body.GetPosition();
				actor.position.x = p.x *100;	// updating actor
				actor.position.y = p.y *100;
				actor.rotation = body.GetAngle();
				if (p.y > - 0.5) {
					ncubes++;
				}
				if ((p.y > 100) && (p.y < min_height)) {
					min_height = p.y - 100;
				}
			}
			
			document.getElementById('cubes').innerHTML = ncubes;
			
			if (ncubes == 0) {
				sm1.position.x = -1010;
			}
			else {
				sm1.position.x = 10;
			}
			
			if (ncubes < 5) {
				sm2.position.x = -1010;
			}
			else {
				sm2.position.x = 10;
			}			
			
			if (ncubes2 > max - 5) {
				sp2.position.x = -340;
			}
			else {
				sp2.position.x = 340;
			}				
			
			if (ncubes2 > max - 1) {
				sp1.position.x = -340;
			}
			else {
				sp1.position.x = 340;
			}	
			
			if ((show_answer == 1) && (ncubes == small)) {
				show_answer = 2;
				
				
				update_progress_bar();

				$('#answer').fadeIn("slow");						
				
				if (product < tries) {
					var next = add_button(54,100,"sugar_next");		
					next.click = next.tap = function(mouseData){
						window.location = "http://howmuchsugar.in/cgi/sugar_random.pl";
					}	
				}
				else {
				
					var y = 100;
					if (height < 750) {
						y = 50;
						$("#results").css("bottom",50);
					}
					if (height < 650) {
						y = 10;
						$("#results").css("bottom",10);
					}
				
					var replay = add_button(54,y,"sugar_replay");		
					replay.click = replay.tap = function(mouseData){
						window.location = "http://howmuchsugar.in/cgi/sugar_random.pl";
					}	
					product = 0;
					
					
					
					var total = 0;
					var debug = '';
					
					var same = 0;
					var less = 0;
					var more = 0;
					var less_n = 0;
					var more_n = 0;
					
					var maxpoints = 0;
					for(var i = 1; i <= tries; i++)
					{
						maxpoints += 10;
						var answer = parseInt($.sessionStorage.getItem('product_answer_' + i)) || 0;
						var actual = parseInt($.sessionStorage.getItem('product_actual_' + i)) || 0;
						var points = parseInt($.sessionStorage.getItem('product_points_' + i)) || 0;
						//$.sessionStorage.setItem('product_name_' + product, small_f);
						
						total += points;
						
						if (points < 10) {
							if (answer < actual) {
								less++;
								less_n += (actual - answer);
							}
							else {
								more++;
								more_n += (answer - actual);
							}
						}
						else {
							same++;
						}
						
					}
					
					var stats = '';
					if (same > 0) {
						var p = same + " products";
						if (same == 1) {
							p = "1 product";
						}
						stats += "<p>You found the right amount of sugar cubes for " + p + ", congratulations!</p>";
					}
					if (less > 0) {
						var p = less + " products";
						if (less == 1) {
							p = "1 product.";
						}
						var m = less_n + " cubes";
						if (less_n == 1) {
							m = "1 cube";
						}
						stats += "<p>You under-estimated the quantity of sugar for " + p + " : " + m + " missing.</p>";
					}					
					if (more > 0) {
						var p = more + " products";
						if (more == 1) {
							p = "1 product.";
						}
						var m = more_n + " cubes";
						if (more_n == 1) {
							m = "1 cube";
						}
						stats += "<p>You over-estimated the quantity of sugar for " + p + " : " + m + " extra.</p>";
					}						
					
					
					$("#score").html('' + total + ' / ' + maxpoints);
					$("#score_share").html('<p>Share your score on x:<br/>' +
'<iframe allowtransparency="true" frameborder="0" scrolling="no" role="presentation" src="http://platform.x.com/widgets/tweet_button.html?via=OpenFoodFactsUK&amp;size=large&amp;count=none&amp;lang=en&amp;text='
+ total + "%2F" + maxpoints + "!%20Guessing%20how%20much%20sugar%20food%20products%20contain%20is%20a%20piece%20of%20cake!%20Try%20it!"
+ '&amp;url=http%3A%2F%2Fhowmuchsugar.in" style="width:200px;height:30px;"></iframe></p>'
					);
					$("#score_stats").html(stats);
			
						
					$("#results").show();
						
				}
				
				$.sessionStorage.setItem('product', product);

			}
			
			
			renderer.render(stage);
			requestAnimFrame(animate);
		}
		

         
         //helpers
         
         //http://js-tut.aardon.de/js-tut/tutorial/position.html
         function getElementPosition(element) {
            var elem=element, tagname="", x=0, y=0;
           
            while((typeof(elem) == "object") && (typeof(elem.tagName) != "undefined")) {
               y += elem.offsetTop;
               x += elem.offsetLeft;
               tagname = elem.tagName.toUpperCase();

               if(tagname == "BODY")
                  elem=0;

               if(typeof(elem) == "object") {
                  if(typeof(elem.offsetParent) == "object")
                     elem = elem.offsetParent;
               }
            }

            return {x: x, y: y};
         }
		 

		 
		 requestAnimFrame( animate );
		 
		//parent.document.getElementById('cubes').innerHTML = 3;
	
	}
	

function save_drawing() {
 var canvas = document.getElementById("c");
 window.open(canvas.toDataURL("image/png"));
}

