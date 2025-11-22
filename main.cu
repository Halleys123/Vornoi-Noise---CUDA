#undef UNICODE

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <Windows.h>
#include <omp.h>
#include <cuda.h>
#include <cuda_gl_interop.h>

#include "WndProc.h"
#include "Colors.h"

#pragma comment( linker, "/subsystem:windows" )

extern "C" __declspec(dllexport) DWORD NvOptimusEnablement = 0x00000001;
DWORD AmdPowerXpressRequestHighPerformance = 0x00000001;

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR cmd, int nCmdShow) {
    if (AttachConsole(ATTACH_PARENT_PROCESS) || AllocConsole()) {
        FILE* stream = nullptr;
        freopen_s(&stream, "CONOUT$", "w", stdout);
        freopen_s(&stream, "CONOUT$", "w", stderr);
        freopen_s(&stream, "CONIN$", "r", stdin);
    }

    printf("\n%sProgram is running%s\n", GREEN_TEXT, RESET);

    WNDCLASS wndClass = {0};
    wndClass.style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
    wndClass.lpfnWndProc = WndProc;
    wndClass.hInstance = hInstance;
    wndClass.hbrBackground = CreateSolidBrush(RGB(40,40,40));
    wndClass.lpszClassName = "Interoperability";
    
    RegisterClass(&wndClass);

    HWND hWnd = CreateWindow(wndClass.lpszClassName, "Interoperability Practice", WS_OVERLAPPEDWINDOW | WS_VISIBLE, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, NULL, NULL, hInstance, NULL);

    if(!hWnd) {
        printf("%sFailed to create window%s", RED_TEXT, RESET);
        return 1;
    }

    // # CUDA SETTINGS

    MSG msg = {};

    while (GetMessage(&msg, NULL, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
    
    printf("%sClosing the program%s", RED_TEXT, RESET);

    return 0;
}
