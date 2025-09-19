package main

/*
#cgo LDFLAGS: -framework ApplicationServices
#include <ApplicationServices/ApplicationServices.h>

CGEventRef mouseMovedCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    if (type == kCGEventMouseMoved || type == kCGEventLeftMouseDragged || type == kCGEventRightMouseDragged) {
        CGPoint loc = CGEventGetLocation(event);
        *((double*)userInfo) = loc.x;
        *((double*)userInfo + 1) = loc.y;
    }
    return event;
}

int isNil(void *p) {
    return p == NULL;
}
*/
import "C"
import (
	"fmt"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"time"
	"unsafe"

	"github.com/go-gl/gl/v3.3-core/gl"
	"github.com/go-gl/glfw/v3.3/glfw"
)

type point struct{ x, y float32 }

func init() { runtime.LockOSThread() }

func compileShader(source string, shaderType uint32) (uint32, error) {
	shader := gl.CreateShader(shaderType)
	csources, free := gl.Strs(source)
	gl.ShaderSource(shader, 1, csources, nil)
	free()
	gl.CompileShader(shader)

	var status int32
	gl.GetShaderiv(shader, gl.COMPILE_STATUS, &status)
	if status == gl.FALSE {
		var logLength int32
		gl.GetShaderiv(shader, gl.INFO_LOG_LENGTH, &logLength)
		log := make([]byte, logLength)
		gl.GetShaderInfoLog(shader, logLength, nil, &log[0])
		return 0, fmt.Errorf("compile error: %s", log)
	}
	return shader, nil
}

func createProgram() (uint32, error) {
	vertexShaderSrc := `
	#version 330 core
	layout (location = 0) in vec2 aPos;
	void main() {
		gl_Position = vec4(aPos, 0.0, 1.0);
	}`
	fragmentShaderSrc := `
	#version 330 core
	out vec4 FragColor;
	void main() {
		FragColor = vec4(1.0, 0.8, 0.2, 0.7);
	}`

	vs, err := compileShader(vertexShaderSrc+"\x00", gl.VERTEX_SHADER)
	if err != nil {
		return 0, err
	}
	fs, err := compileShader(fragmentShaderSrc+"\x00", gl.FRAGMENT_SHADER)
	if err != nil {
		return 0, err
	}
	program := gl.CreateProgram()
	gl.AttachShader(program, vs)
	gl.AttachShader(program, fs)
	gl.LinkProgram(program)
	gl.DeleteShader(vs)
	gl.DeleteShader(fs)
	return program, nil
}

func main() {
	// CoreGraphics event tap для курсора
	var coords [2]C.double
	tap := C.CGEventTapCreate(
		C.kCGHIDEventTap,
		C.kCGHeadInsertEventTap,
		C.kCGEventTapOptionListenOnly,
		(1<<C.kCGEventMouseMoved)|
			(1<<C.kCGEventLeftMouseDragged)|
			(1<<C.kCGEventRightMouseDragged),
		(C.CGEventTapCallBack)(unsafe.Pointer(C.mouseMovedCallback)),
		unsafe.Pointer(&coords[0]),
	)
	if C.isNil(unsafe.Pointer(tap)) != 0 {
		fmt.Println("Не удалось создать event tap — добавьте бинарь в Accessibility.")
		os.Exit(1)
	}
	source := C.CFMachPortCreateRunLoopSource(C.CFAllocatorRef(unsafe.Pointer(uintptr(0))), tap, 0)
	C.CFRunLoopAddSource(C.CFRunLoopGetCurrent(), source, C.kCFRunLoopCommonModes)
	C.CGEventTapEnable(tap, C.bool(true))
	go C.CFRunLoopRun()

	// GLFW init
	if err := glfw.Init(); err != nil {
		panic(err)
	}
	defer glfw.Terminate()
	glfw.WindowHint(glfw.ContextVersionMajor, 3)
	glfw.WindowHint(glfw.ContextVersionMinor, 3)
	glfw.WindowHint(glfw.OpenGLProfile, glfw.OpenGLCoreProfile)
	glfw.WindowHint(glfw.OpenGLForwardCompatible, glfw.True)
	glfw.WindowHint(glfw.Decorated, glfw.False)
	glfw.WindowHint(glfw.TransparentFramebuffer, 1)
	glfw.WindowHint(glfw.Floating, 1)
	glfw.WindowHint(glfw.Resizable, glfw.False)

	primary := glfw.GetPrimaryMonitor()
	mode := primary.GetVideoMode()
	win, err := glfw.CreateWindow(mode.Width, mode.Height, "Comet Cursor", nil, nil)
	if err != nil {
		panic(err)
	}
	win.MakeContextCurrent()
	glfw.SwapInterval(1)

	if err := gl.Init(); err != nil {
		panic(err)
	}

	// Настройки для прозрачности
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	program, err := createProgram()
	if err != nil {
		panic(err)
	}

	var vao, vbo uint32
	gl.GenVertexArrays(1, &vao)
	gl.GenBuffers(1, &vbo)

	trail := []point{}
	lastUpdate := time.Now()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	go func() { <-stop; win.SetShouldClose(true) }()

	for !win.ShouldClose() {
		// Добавляем точку в хвост
		if time.Since(lastUpdate) > 16*time.Millisecond {
			trail = append(trail, point{x: float32(coords[0]), y: float32(coords[1])})
			if len(trail) > 40 {
				trail = trail[1:]
			}
			lastUpdate = time.Now()
		}

		// Конвертация координат в NDC
		verts := []float32{}
		for _, p := range trail {
			ndcX := (p.x/float32(mode.Width))*2 - 1
			ndcY := (1-p.y/float32(mode.Height))*2 - 1
			verts = append(verts, ndcX, ndcY)
		}

		// Очистка экрана
		gl.ClearColor(0, 0, 0, 0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		// Рисуем только если есть точки
		if len(verts) > 0 {
			gl.BindVertexArray(vao)
			gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
			gl.BufferData(gl.ARRAY_BUFFER, len(verts)*4, gl.Ptr(verts), gl.DYNAMIC_DRAW)
			gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 0, gl.PtrOffset(0))
			gl.EnableVertexAttribArray(0)

			gl.UseProgram(program)
			gl.DrawArrays(gl.LINE_STRIP, 0, int32(len(trail)))
		}

		win.SwapBuffers()
		glfw.PollEvents()
	}

	C.CFRunLoopStop(C.CFRunLoopGetCurrent())
	fmt.Println("Завершено.")
}
