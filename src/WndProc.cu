// glad must be included before any header that might include <GL/gl.h>
#include "glad/glad.h"
#include <cuda_gl_interop.h>
#include <stdio.h>
#include <math.h>
#include <stdlib.h>

#include "WndProc.h"
#include "PixelFormat.h"
#include "Colors.h"

typedef struct coord {
    int x;
    int y;
} coord;

__global__ void kernel(uchar4* devPtr, float timeSeconds, int width, int height, int x_divs, int y_divs, coord* seeds, int seeds_per_block) {
    int x = threadIdx.x + blockDim.x * blockIdx.x;
    int y = threadIdx.y + blockDim.y * blockIdx.y;

    int offset = x + y * width;

    if(x >= width || y >= height) return;

    int div_width = (width + x_divs - 1) / x_divs;
    int div_height = (height + y_divs - 1) / y_divs;
    int x_block = min(x / div_width, x_divs - 1);
    int y_block = min(y / div_height, y_divs - 1);

    int min_distance = INT_MAX;
    int max_distance = (int)sqrtf(4 * div_height * div_height + 4 * div_width * div_width);
    
    for(int col = -1;col <= 1;col += 1) {
        for(int row = -1;row <= 1;row += 1) {
            int new_x_block = col + x_block;
            int new_y_block = row + y_block;

            if(new_x_block >= 0 && new_x_block < x_divs && new_y_block >= 0 && new_y_block < y_divs) {
                int block_offset = new_x_block + new_y_block * x_divs;
                for(int j = 0;j < seeds_per_block;j += 1) {
                    int idx = block_offset * seeds_per_block + j;
                    int dx = seeds[idx].x - x;
                    int dy = seeds[idx].y - y;
                    min_distance = min((int)sqrtf(dx*dx + dy*dy), min_distance);
                }
            }
        }
    }
    float value = sqrtf((float)min_distance) / sqrtf(max_distance);
    value = fminf(fmaxf(value, 0.0f), 1.0f);

    unsigned char g = (unsigned char)(value * 255.0f);
    devPtr[offset].x = g;
    devPtr[offset].y = g;
    devPtr[offset].z = g;
    devPtr[offset].w = 255;
}

static void generateSeeds(coord* seeds, int seeds_per_block, int x_divs, int y_divs, int width, int height) {
    int div_width  = (width  + x_divs - 1) / x_divs;
    int div_height = (height + y_divs - 1) / y_divs;

    for (int row = 0; row < y_divs; row++) {
        for (int col = 0; col < x_divs; col++) {
            for (int i = 0; i < seeds_per_block; i++) {
                int idx = (col + row * x_divs) * seeds_per_block + i;
                seeds[idx].x = col * div_width  + rand() % div_width;
                seeds[idx].y = row * div_height + rand() % div_height;
            }
        }
    }
}

#ifdef __cplusplus
extern "C"
{
#endif

    LRESULT CALLBACK WndProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
    {
        static int height, width;

        static HGLRC RenderingContext;
        static HDC DeviceContext;

        static GLuint PBO;
        static cudaGraphicsResource *resource;
        static uchar4* devPtr;
        static size_t size;

        static dim3 grids;
        static dim3 threads;

        static const UINT_PTR TIMER_ID = 1;
        static const UINT TIMER_INTERVAL_MS = 33;

        static RECT rect;
        static LARGE_INTEGER startCounter;
        static double invPerfFrequency = 0.0;
        static bool usePerfCounter = false;

        static int seeds_per_block = 3;
        static int x_divs = 3, y_divs = 3;
        static coord* h_seeds;
        static coord* d_seeds;
        static char current_slection = ' ';

        switch (uMsg)
        {
        case WM_CREATE:
        {
            DeviceContext = GetDC(hWnd);
            PixelFormat(DeviceContext);
            RenderingContext = wglCreateContext(DeviceContext);
            wglMakeCurrent(DeviceContext, RenderingContext);
            
            if (!gladLoadGL()) {
                printf("%sFailed to initialize GLAD%s\n", RED_TEXT, RESET);
                return -1;
            }
            
            printf("%sRendering content loaded successfully.%s\n", GREEN_TEXT, RESET);

            GetClientRect(hWnd, &rect);

            width = rect.right - rect.left;
            height = rect.bottom - rect.top;

            threads = dim3(24, 24);
            grids = dim3((width + threads.x - 1) / threads.x, (height + threads.y - 1) / threads.y);

            glGenBuffers(1, &PBO);
            glBindBuffer(GL_PIXEL_UNPACK_BUFFER_ARB, PBO);
            glBufferData(GL_PIXEL_UNPACK_BUFFER_ARB, height * width * 4, NULL, GL_DYNAMIC_DRAW_ARB);

            cudaError_t regStatus = cudaGraphicsGLRegisterBuffer(&resource, PBO, cudaGraphicsMapFlagsNone);
            if (regStatus != cudaSuccess) {
                printf("%sFailed to register GL buffer with CUDA: %s%s\n", RED_TEXT, cudaGetErrorString(regStatus), RESET);
                return -1;
            }

            if (!SetTimer(hWnd, TIMER_ID, TIMER_INTERVAL_MS, NULL)) {
                printf("%sFailed to create render timer.%s\n", RED_TEXT, RESET);
                return -1;
            }


            LARGE_INTEGER frequency;
            if (QueryPerformanceFrequency(&frequency)) {
                invPerfFrequency = 1.0 / static_cast<double>(frequency.QuadPart);
                QueryPerformanceCounter(&startCounter);
                usePerfCounter = true;
            } else {
                startCounter.QuadPart = static_cast<LONGLONG>(GetTickCount64());
                invPerfFrequency = 1.0 / 1000.0;
                usePerfCounter = false;
            }

            h_seeds = (coord*)malloc(sizeof(coord) * x_divs * y_divs * seeds_per_block);
            generateSeeds(h_seeds, seeds_per_block, x_divs, y_divs, width, height);

            cudaMalloc((void**)&d_seeds, sizeof(coord) * seeds_per_block * x_divs * y_divs);
            cudaMemcpy(d_seeds, h_seeds, sizeof(coord) * seeds_per_block * x_divs * y_divs, cudaMemcpyHostToDevice);
            return 0;
        }

        case WM_KEYDOWN:
        {
            if(wParam == 'x' || wParam == 'X') {
                current_slection = 'x';
            }
            else if(wParam == 'y' || wParam == 'Y') {
                current_slection = 'y';
            } 
            else if(wParam == ' ') {
                current_slection = ' ';
            } 

            if((wParam == VK_OEM_MINUS || wParam == VK_OEM_PLUS) && current_slection != ' ') {
                if(wParam == VK_OEM_MINUS) {
                    if(current_slection == 'x') x_divs = x_divs - 1 > 0 ? x_divs - 1 : 1;
                    else y_divs = y_divs - 1 > 0 ? y_divs - 1 : 1;
                } 
                else {
                    if(current_slection == 'x') x_divs += 1;
                    else y_divs += 1;
                }
                free(h_seeds);
                h_seeds = (coord*)malloc(sizeof(coord) * x_divs * y_divs * seeds_per_block);
                generateSeeds(h_seeds, seeds_per_block, x_divs, y_divs, width, height);
                cudaFree(d_seeds);
                cudaMalloc((void**)&d_seeds, sizeof(coord) * seeds_per_block * x_divs * y_divs);
                cudaMemcpy(d_seeds, h_seeds, sizeof(coord) * seeds_per_block * x_divs * y_divs, cudaMemcpyHostToDevice);

            }

            printf("X_DIVS Y_DIVS = %s%d %d%s\n", GREEN_TEXT, x_divs, y_divs, RESET);

            InvalidateRect(hWnd, NULL, FALSE);

            return 0;
        }

        case WM_SIZE:
        {            
            GetClientRect(hWnd, &rect);
            height = rect.bottom - rect.top;
            width = rect.right - rect.left;

            free(h_seeds);
            h_seeds = (coord*)malloc(sizeof(coord) * x_divs * y_divs * seeds_per_block);
            generateSeeds(h_seeds, seeds_per_block, x_divs, y_divs, width, height);
            cudaMemcpy(d_seeds, h_seeds, sizeof(coord) * seeds_per_block * x_divs * y_divs, cudaMemcpyHostToDevice);

            grids = dim3((width + threads.x - 1) / threads.x, (height + threads.y - 1) / threads.y);

            glBindBuffer(GL_PIXEL_UNPACK_BUFFER_ARB, PBO);
            glBufferData(GL_PIXEL_UNPACK_BUFFER_ARB, height * width * 4, NULL, GL_DYNAMIC_DRAW_ARB);

            cudaError_t regStatus = cudaGraphicsGLRegisterBuffer(&resource, PBO, cudaGraphicsMapFlagsNone);
            if (regStatus != cudaSuccess) {
                printf("%sFailed to register GL buffer with CUDA: %s%s\n", RED_TEXT, cudaGetErrorString(regStatus), RESET);
                return -1;
            }


            InvalidateRect(hWnd, &rect, FALSE);

            return 0;
        }
        case WM_TIMER:
        {
            if (wParam != TIMER_ID) {
                break;
            }

            cudaGraphicsMapResources(1, &resource, NULL);
            cudaGraphicsResourceGetMappedPointer((void**)&devPtr, &size, resource);

            double elapsedSeconds = 0.0;
            if (usePerfCounter) {
                LARGE_INTEGER now;
                QueryPerformanceCounter(&now);
                elapsedSeconds = (now.QuadPart - startCounter.QuadPart) * invPerfFrequency;
            } else {
                ULONGLONG nowMs = GetTickCount64();
                elapsedSeconds = (nowMs - static_cast<ULONGLONG>(startCounter.QuadPart)) * 0.001;
            }

            float frameTime = static_cast<float>(elapsedSeconds);

            kernel<<<grids, threads>>>(devPtr, frameTime, width, height, x_divs, y_divs, d_seeds, seeds_per_block);
            cudaDeviceSynchronize();

            cudaGraphicsUnmapResources(1, &resource, 0);

            InvalidateRect(hWnd, &rect, FALSE);
            UpdateWindow(hWnd);
            return 0;
        }
        case WM_PAINT:
        {
            glBindBuffer(GL_PIXEL_UNPACK_BUFFER_ARB, PBO);

            glDrawPixels(width, height, GL_RGBA, GL_UNSIGNED_BYTE, 0);
            SwapBuffers(DeviceContext);

            glBindBuffer(GL_PIXEL_UNPACK_BUFFER_ARB, 0);

            ValidateRect(hWnd,  &rect);

            return 0;
        }
        case WM_CLOSE:
        {   
            free(h_seeds);
            cudaFree(d_seeds);
            cudaGraphicsUnregisterResource(resource);
            glDeleteBuffers(1, &PBO);
            KillTimer(hWnd, TIMER_ID);

            PostQuitMessage(0);
            wglDeleteContext(RenderingContext);
            return 0;
        }
        case WM_DESTROY:
        {
            ReleaseDC(hWnd, DeviceContext);
            return 0;
        }

        default:
            break;
        }

        return DefWindowProc(hWnd, uMsg, wParam, lParam);
    }

#ifdef __cplusplus
}
#endif