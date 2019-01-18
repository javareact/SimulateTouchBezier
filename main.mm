/*
 * Name: libSimulateTouch
 * Author: iolate <iolate@me.com>
 *
 */

#import <CoreGraphics/CoreGraphics.h>
#import "SimulateTouch.h"

#define PRINT_USAGE printf("[Usage]\n 1. Touch:\n    %s touch x y [orientation]\n\n 2. Swipe:\n   %s swipe fromX fromY toX toY [duration(0.3)] [orientation]\n\n 3. Button: \n    %s button Type State\n\n[Example]\n   # %s touch 50 100\n   # %s swipe 50 100 100 200 0.5\n   # %s button 0 1\n   # %s button 1 0\n\n[Orientation]\n    Portrait:1 UpsideDown:2 Right:3 Left:4\n\n[Button]\n    Power:0 Home:1\n\n[State]\n    Up/Raise:0 Down/Press:1\n\n", argv[0], argv[0], argv[0], argv[0], argv[0], argv[0], argv[0]);

int main(int argc, char **argv, char **envp) {
    if (argc == 1) {
        PRINT_USAGE;
        return 0;
    }
    
    if (!strcmp(argv[1], "touch")) {
        if (argc != 4 && argc != 5) {
            PRINT_USAGE;
            return 0;
        }
        
        if (argc == 4) {
            int x = atoi(argv[2]);
            int y = atoi(argv[3]);
            
            int r = [SimulateTouch simulateTouch:0 atPoint:CGPointMake(x, y) withType:STTouchDown];
            [SimulateTouch simulateTouch:r atPoint:CGPointMake(x, y) withType:STTouchUp];
        }else if (argc == 5) {
            int px = atoi(argv[2]);
            int py = atoi(argv[3]);
            CGPoint p = CGPointMake(px, py);
            
            CGPoint rp = [SimulateTouch STWindowToScreenPoint:p withOrientation:atoi(argv[4])];
            int r = [SimulateTouch simulateTouch:0 atPoint:rp withType:STTouchDown];
            [SimulateTouch simulateTouch:r atPoint:rp withType:STTouchUp];
        }
        
    }else if (!strcmp(argv[1], "swipe")) {
        if (argc < 6 || argc > 13) {
            PRINT_USAGE;
            return 0;
        }
        
        float duration = 0.3f;
          
            CGPoint pfromPoint = CGPointMake(atoi(argv[2]), atoi(argv[3]));
            CGPoint ptoPoint = CGPointMake(atoi(argv[4]), atoi(argv[5]));

            CGPoint fromPoint = [SimulateTouch STWindowToScreenPoint:pfromPoint withOrientation:atoi(argv[7])];
            CGPoint toPoint = [SimulateTouch STWindowToScreenPoint:ptoPoint withOrientation:atoi(argv[7])];

            duration = atof(argv[6]);
            float p1x = atof(argv[8]);
            float p1y = atof(argv[9]);
            float p2x = atof(argv[10]);
            float p2y = atof(argv[11]);
            [SimulateTouch simulateSwipeFromPoint:fromPoint toPoint:toPoint duration:duration p1x:p1x p1y:p1y p2x:p2x p2y:p2y];

        
        CFRunLoopRunInMode(kCFRunLoopDefaultMode , duration+0.1f, NO);
    }else if (!strcmp(argv[1], "button")) {
        if (argc != 4) {
            PRINT_USAGE;
            return 0;
        }
        
        int button = atoi(argv[2]);
        int state  = atoi(argv[3]);
        
        [SimulateTouch simulateButton:button state:state];
    }else{
        PRINT_USAGE;
        return 0;
    }
    
    return 0;
}
