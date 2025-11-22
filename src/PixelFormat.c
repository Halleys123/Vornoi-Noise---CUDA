#include "PixelFormat.h"

#ifdef __cplusplus
extern "C"
{
#endif

    void PixelFormat(HDC hdc)
    {
        PIXELFORMATDESCRIPTOR pfd = {
            sizeof(PIXELFORMATDESCRIPTOR),                              // nSize
            1,                                                          // nVersion
            PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER, // More
            PFD_TYPE_RGBA,                                              // iPixelType
            32,                                                         // cColorBits
            0, 0, 0, 0, 0, 0,                                           // cRedBits, cRedShift, cGreenBits, cGreenShift, cBlueBits, cBlueShift
            0,                                                          // cAlphaBits
            0,                                                          // cAlphaShift
            0,                                                          // cAccumBits
            0, 0, 0, 0,                                                 // cAccumRedBits, cAccumGreenBits, cAccumBlueBits, cAccumAlphaBits
            24,                                                         // cDepthBits
            8,                                                          // cStencilBits
            0,                                                          // cAuxBuffers
            PFD_MAIN_PLANE,                                             // iLayerType
            0,                                                          // bReserved
            0, 0, 0                                                     // dwLayerMask, dwVisibleMask, dwDamageMask
        };
        int pixelFormat = ChoosePixelFormat(hdc, &pfd);
        SetPixelFormat(hdc, pixelFormat, &pfd);
    }

#ifdef __cplusplus
}
#endif
