/*
 * UIApplication2.h
 *
 * iolate <iolate@me.com>
 */

#if __cplusplus
extern "C" {
#endif
    
    size_t UIApplicationInitialize();
    void UIApplicationInstantiateSingleton(Class singletonClass);
    
#if __cplusplus
}
#endif