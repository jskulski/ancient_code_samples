import processing.core.*; import java.applet.*; import java.awt.*; import java.awt.image.*; import java.awt.event.*; import java.io.*; import java.net.*; import java.text.*; import java.util.*; import java.util.zip.*; import javax.sound.midi.*; import javax.sound.midi.spi.*; import javax.sound.sampled.*; import javax.sound.sampled.spi.*; import java.util.regex.*; import javax.xml.parsers.*; import javax.xml.transform.*; import javax.xml.transform.dom.*; import javax.xml.transform.sax.*; import javax.xml.transform.stream.*; import org.xml.sax.*; import org.xml.sax.ext.*; import org.xml.sax.helpers.*; public class ParticleSys extends PApplet {/**
 * Simple Particle System Thinger
 * jskulski
 **/

ArrayList particles;
ArrayList bars;
ArrayList hbars;

public static final int TYPE_BAR = 0;
public static final int TYPE_HBAR = 1;

int TYPE = TYPE_BAR; 

public void setup() {
  size(640,480);
  
  smooth();
  
  particles = new ArrayList();
  bars = new ArrayList();
  hbars = new ArrayList();
  
  bars.add(new Bar(width/2,height/2));
}

public void draw() {
  
  // switch type if spacebar
  if (keyPressed) {
     if (TYPE == 0) {
       TYPE++;
     } else { 
       TYPE = 0;
     } 
  }
 
  System.out.println(particles.size());
  background(0);
  
  particles.add(new Particle(width/2,0));
   
  // iterate through Particles
  for (int i = particles.size()-1; i >= 0; i--) {
    
    Particle p = (Particle) particles.get(i);
    p.run();  
    p.gravity();
    p.draw();
    
    // iterate through Obstacles / collisions and render
    for (int j = bars.size()-1; j >= 0; j--) { 
      Bar b = (Bar) bars.get(j);
      b.collide(p);
    }    
    for (int j = hbars.size()-1; j >= 0; j--) { 
      HBar b = (HBar) hbars.get(j);
      b.collide(p);
    }    
    
    // remove if 'gone' ()
    if (p.gone()) { 
       particles.remove(i); 
    }
  }
      
  // Bars    
  for (int j = bars.size()-1; j >= 0; j--) { 
      Bar b = (Bar) bars.get(j);
      b.draw();
  }
  
  // HBars
  for (int j = hbars.size()-1; j >= 0; j--) { 
      HBar b = (HBar) hbars.get(j);
      b.draw();
  }    
    
}

public void mousePressed() { 
  switch (TYPE) { 
    case TYPE_BAR:   
      bars.add(new Bar(mouseX,mouseY));
      break;
    case TYPE_HBAR:
      hbars.add(new HBar(mouseX,mouseY));
      break;
  }
}

// CLASSES

public class Particle {
 
  float x, y;
  float xspeed, yspeed; 
  
  float timer = 255;
  float r;
  
  Particle (float xpos, float ypos) { 
     x = xpos;
     y = ypos;
     r = random(3, 15);
   
     //c = color(random(255),random(255),random(255));
     
     // blatently used from other particle systems
     float theta = random(PI,TWO_PI);
     float rand = random(0.5f,1);
     xspeed = rand*cos(theta);
     yspeed = rand*sin(theta);
   } 
  
  public void run() { 
    x = x + xspeed;
    y = y + yspeed;
    timer -= 1.5f;
  }
  
  public void gravity() {
     yspeed += 0.05f; 
  }
  
  public boolean gone() { 
     if (timer < 0) {
        return true;
     } 
     return false;
  }
  
  public void draw() { 
    fill(255, timer); // fade out
    noStroke();
    ellipse(x,y,r,r);
  }
}


/*interface Obstacle { 
  void collide();
  void collide(Particle p);
  void draw();
}*/

class HBar { 
   Rectangle r;
   
   HBar (int x, int y) { 
       r = new Rectangle(x,y-25,5,50);
   }

   public void collide(Particle p) { 
     if (r.contains(p.x,p.y)) {
      //reverse
      p.xspeed *= -0.5f;
      p.x += p.xspeed; 
      // reset timer
      p.timer = 255;
     }
   }  
   
   public void draw() {
      fill(127);
      stroke(200);
      rect(r.x,r.y,r.width,r.height);
    }
}

class Bar  { 
  
    Rectangle r;
   
    Bar (int x, int y) {
        r = new Rectangle(x-25,y,50,5);
    } 
    
    public void collide(Particle p) { 
      if (r.contains(p.x,p.y)) {
         //reverse
         p.yspeed *= -0.5f;
         p.y += p.yspeed; 
         // reset timer
         p.timer = 255;
       }
     }
      
    public void draw() {
      fill(127);
      stroke(200);
      rect(r.x,r.y,r.width,r.height);
    }
}


  static public void main(String args[]) {     PApplet.main(new String[] { "ParticleSys" });  }}
