/*
 * Name: libSimulateTouch
 * Author: iolate <iolate@me.com>
 *
 */

#import <mach/mach_time.h>
#import <CoreGraphics/CoreGraphics.h>
#import <rocketbootstrap.h>

#define LOOP_TIMES_IN_SECOND 1000
//60
#define MACH_PORT_NAME "kr.iolate.simulatetouch"

typedef enum {
    STTouchMove = 0,
    STTouchDown,
    STTouchUp,

    // For these types, (int)point_x denotes button type
    STButtonUp,
    STButtonDown
} STTouchType;

typedef struct {
    int type;       // STTouchType values
    int index;      // pathIndex holder in message
    float point_x;
    float point_y;
} STEvent;

//typedef enum {
//    UIInterfaceOrientationPortrait           = 1,//UIDeviceOrientationPortrait,
//    UIInterfaceOrientationPortraitUpsideDown = 2,//UIDeviceOrientationPortraitUpsideDown,
//    UIInterfaceOrientationLandscapeLeft      = 4,//UIDeviceOrientationLandscapeRight,
//    UIInterfaceOrientationLandscapeRight     = 3,//UIDeviceOrientationLandscapeLeft
//} UIInterfaceOrientation;

//@interface UIScreen
//+(id)mainScreen;
//-(CGRect)bounds;
//@end

@interface STTouchA : NSObject
{
@public
    int type; //터치 종류 0: move/stay| 1: down| 2: up
    int pathIndex;
    CGPoint startPoint;
    CGPoint endPoint;
    uint64_t startTime;
    float requestedTime;
    float p1x,p1y,p2x,p2y;
}
@end
@implementation STTouchA
@end

static CFMessagePortRef messagePort = NULL;
static NSMutableArray* ATouchEvents = nil;
static BOOL FTLoopIsRunning = FALSE;

#pragma mark -

static int send_event(STEvent *event) {
    if (messagePort && !CFMessagePortIsValid(messagePort)){
        CFRelease(messagePort);
        messagePort = NULL;
    }
    if (!messagePort) {
        messagePort = rocketbootstrap_cfmessageportcreateremote(NULL, CFSTR(MACH_PORT_NAME));
        //messagePort = CFMessagePortCreateRemote(NULL, CFSTR(MACH_PORT_NAME));
    }
    if (!messagePort || !CFMessagePortIsValid(messagePort)) {
        NSLog(@"ST Error: MessagePort is invalid");
        return 0; //kCFMessagePortIsInvalid;
    }

    CFDataRef cfData = CFDataCreate(NULL, (uint8_t*)event, sizeof(*event));
    CFDataRef rData = NULL;
    
    CFMessagePortSendRequest(messagePort, 1/*type*/, cfData, 1, 1, kCFRunLoopDefaultMode, &rData);
    
    if (cfData) {
        CFRelease(cfData);
    }
    
    int pathIndex;
    [(NSData *)rData getBytes:&pathIndex length:sizeof(pathIndex)];
    
    if (rData) {
        CFRelease(rData);
    }
    
    return pathIndex;
}

static int simulate_button_event(int index, int button, int state) {
    STEvent event;
    event.index = index;
    
    event.type    = (int)STButtonUp + state;
    event.point_x = button;
    event.point_y = 0.0f;

    return send_event(&event);
}

static int simulate_touch_event(int index, int type, CGPoint point) {
    STEvent event;
    event.index = index;
    
    event.type = type;
    event.point_x = point.x;
    event.point_y = point.y;
    
    return send_event(&event);
}

double MachTimeToSecs(uint64_t time)
{
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    return (double)time * (double)timebase.numer / (double)timebase.denom / 1e9;
}

double func(double x,double a,double b,double c,double d) //原函数
{
    return a*x*x*x+b*x*x+c*x+d;
}
double func1(double x,double a,double b,double c,double d) //导函数
{
    return 3*a*x*x+2*b*x+c;
}
int Newton(double *x,double precision,int maxcyc,double a,double b,double c,double d) //迭代次数
{
    double x1,x0;
    int k;
    x0=*x;
    for(k=0;k<maxcyc;k++)
    {
        if(func1(x0,a,b,c,d)==0.0)//若通过初值，函数返回值为0
        {
            NSLog(@"迭代过程中导数为0!\n");
            return 0;
        }
        x1=x0-func(x0,a,b,c,d)/func1(x0,a,b,c,d);//进行牛顿迭代计算
        if(fabs(x1-x0)<precision || fabs(func(x1,a,b,c,d))<precision) //达到结束条件
        {
            *x=x1; //返回结果
            return 1;
        }
        else //未达到结束条件
        {
            x0=x1; //准备下一次迭代
        }
    }
    NSLog(@"迭代次数超过预期！\n"); //迭代次数达到，仍没有达到精度
    return 0;
}

double bezier_y(double p1x,double p1y,double p2x,double p2y,double x,int *success)
{
    double ax = 3 * p1x - 3 * p2x + 1,  
          bx = 3 * p2x - 6 * p1x,  
          cx = 3 * p1x;  
      
    double ay = 3 * p1y - 3 * p2y + 1,  
          by = 3 * p2y - 6 * p1y,  
          cy = 3 * p1y;  

    double t=0.5,precision=0.0001;
    int maxcyc=100;
    //根据x用牛顿迭代法算出t
    if(Newton(&t,precision,maxcyc,ax,bx,cx,-x)==1) //若函数返回值为1
    {
        if(t>=0 && t<=1){
          *success=1;
        }else{
          *success=0;
        }
        NSLog(@"该值附近的根为：%lf\n",t);
    }
    else //若函数返回值为0
    {
        *success=0;
        NSLog(@"迭代失败！\n");
    }
    return ((ay * t + by) * t + cy ) * t;
}


static void _simulateTouchLoop()
{
    if (FTLoopIsRunning == FALSE) {
        return;
    }
    int touchCount = [ATouchEvents count];
    NSLog(@"ST touchCount: %d",touchCount);    
    if (touchCount == 0) {
        FTLoopIsRunning = FALSE;
        return;
    }
    
    NSMutableArray* willRemoveObjects = [NSMutableArray array];
    uint64_t curTime = mach_absolute_time();
    
    for (int i = 0; i < touchCount; i++)
    {
        STTouchA* touch = [ATouchEvents objectAtIndex:i];
        
        int touchType = touch->type;
        //0: move/stay 1: down 2: up
        
        if (touchType == 1) {
            //Already simulate_touch_event is called
            touch->type = STTouchMove;
        }else {
            double dif = MachTimeToSecs(curTime - touch->startTime);
            
            float req = touch->requestedTime;
            if (dif >= 0 && dif < req) {
                //Move
                
                float dx = touch->endPoint.x - touch->startPoint.x;
                float dy = touch->endPoint.y - touch->startPoint.y;
		        float x = (float)dif / req;
                int success=0;
                float per=bezier_y((double)touch->p1x,(double)touch->p2x,(double)touch->p1y,(double)touch->p2y,(double)x,&success);
			    if(success!=1){
                   NSLog(@"没有算出Y值");
                   continue; 
                }
                //req 是总时间
                //dif 是已花费的时间
                //per 是进度
	           	NSLog(@"ST LLL: x:%f",x);
                NSLog(@"ST LLL: y:%f",per);
                CGPoint point = CGPointMake(touch->startPoint.x + (float)(dx * per), touch->startPoint.y + (float)(dy * per));
                int r=simulate_touch_event(touch->pathIndex, STTouchMove, point);

               if (r == 0) {
                   NSLog(@"ST Error: touchLoop type:0 index:%d, point:(%d,%d) pathIndex:0", touch->pathIndex, (int)point.x, (int)point.y);
                   continue;
               } 

                
            }else {
                //Up
                simulate_touch_event(touch->pathIndex, STTouchMove, touch->endPoint);
                int r = simulate_touch_event(touch->pathIndex, STTouchUp, touch->endPoint);
                if (r == 0) {
                    NSLog(@"ST Error: touchLoop type:2 index:%d, point:(%d,%d) pathIndex:0", touch->pathIndex, (int)touch->endPoint.x, (int)touch->endPoint.y);
                    continue;
                }
                
                [willRemoveObjects addObject:touch];
            }
        }
    }
    
    for (STTouchA* touch in willRemoveObjects) {
        [ATouchEvents removeObject:touch];
        [touch release];
    }
    
    willRemoveObjects = nil;
    
    //recursive
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / LOOP_TIMES_IN_SECOND);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        _simulateTouchLoop();
    });
}

#pragma mark -

@interface SimulateTouch : NSObject
@end

@implementation SimulateTouch

+(CGPoint)STScreenToWindowPoint:(CGPoint)point withOrientation:(UIInterfaceOrientation)orientation {
    CGSize screen = [[UIScreen mainScreen] bounds].size;
    
    if (orientation == UIInterfaceOrientationPortrait) {
        return point;
    }else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
        return CGPointMake(screen.width - point.x, screen.height - point.y);
    }else if (orientation == UIInterfaceOrientationLandscapeLeft) {
        //Homebutton is left
        return CGPointMake(screen.height - point.y, point.x);
    }else if (orientation == UIInterfaceOrientationLandscapeRight) {
        return CGPointMake(point.y, screen.width - point.x);
    }else return point;
}

+(CGPoint)STWindowToScreenPoint:(CGPoint)point withOrientation:(UIInterfaceOrientation)orientation {
    CGSize screen = [[UIScreen mainScreen] bounds].size;
    
    if (orientation == UIInterfaceOrientationPortrait) {
        return point;
    }else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
        return CGPointMake(screen.width - point.x, screen.height - point.y);
    }else if (orientation == UIInterfaceOrientationLandscapeLeft) {
        //Homebutton is left
        return CGPointMake(point.y, screen.height - point.x);
    }else if (orientation == UIInterfaceOrientationLandscapeRight) {
        return CGPointMake(screen.width - point.y, point.x);
    }else return point;
}

+(int)simulateButton:(int)button state:(int)state
{
    int r = simulate_button_event(0, button, state);
    
    if (r == 0) {
        NSLog(@"ST Error: simulateButton:state: button:%d state:%d pathIndex:0", button, state);
        return 0;
    }
    return r;
}

+(int)simulateTouch:(int)pathIndex atPoint:(CGPoint)point withType:(STTouchType)type
{
    int r = simulate_touch_event(pathIndex, type, point);
    
    if (r == 0) {
        NSLog(@"ST Error: simulateTouch:atPoint:withType: index:%d type:%d pathIndex:0", pathIndex, type);
        return 0;
    }
    return r;
}

+(int)simulateSwipeFromPoint:(CGPoint)fromPoint toPoint:(CGPoint)toPoint duration:(float)duration p1x:(float)p1x p1y:(float)p1y p2x:(float)p2x p2y:(float)p2y
{
    if (ATouchEvents == nil) {
        ATouchEvents = [[NSMutableArray alloc] init];
    }
    
    STTouchA* touch = [[STTouchA alloc] init];
    
    touch->type = STTouchMove;
    touch->startPoint = fromPoint;
    touch->endPoint = toPoint;
    touch->requestedTime = duration;
    touch->startTime = mach_absolute_time();
    touch->p1x = p1x;
    touch->p2x = p2x;
    touch->p1y = p1y;
    touch->p2y = p2y;    


    [ATouchEvents addObject:touch];
    
    int r = simulate_touch_event(0, STTouchDown, fromPoint);
    if (r == 0) {
        NSLog(@"ST Error: simulateSwipeFromPoint:toPoint:duration: pathIndex:0");
        return 0;
    }
    touch->pathIndex = r;
    
    if (!FTLoopIsRunning) {
        FTLoopIsRunning = TRUE;
        _simulateTouchLoop();
    }
    
    return r;
}

@end
