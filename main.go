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
	// Вход: позиция вершины (2D)
	// Вход: значение прозрачности
	// Выход: передаем прозрачность в фрагментный шейдер
	// Преобразуем в 4D позицию (3D + homogeneous)
	// Передаем прозрачность дальше
	vertexShaderSrc := `
	#version 330 core
	layout (location = 0) in vec2 aPos; 
	layout (location = 1) in float aAlpha;
	out float vAlpha;
	void main() {
		gl_Position = vec4(aPos, 0.0, 1.0);
		vAlpha = aAlpha;
	}`
	//fragmentShaderSrc := `
	//#version 330 core
	//in float vAlpha;
	//out vec4 FragColor;
	//void main() {
	//	// Создаем градиент от оранжевого (1.0, 0.4, 0.0) к желтому (1.0, 1.0, 0.2)
	//	vec3 color = mix(vec3(1.0, 0.4, 0.0), vec3(1.0, 1.0, 0.2), vAlpha);
	//	// Устанавливаем цвет с прозрачностью (альфа = 80% от входного значения)
	//	FragColor = vec4(color, vAlpha * 0.8);
	//}`
	fragmentShaderSrc := `
#version 330 core
in float vAlpha;
out vec4 FragColor;

void main() {
    // Широкий градиент с нелинейным распределением
    float gradientFactor = smoothstep(0.0, 1.0, vAlpha);
    gradientFactor = pow(gradientFactor, 0.3); // Делаем градиент шире
    
    vec3 startColor = vec3(0.8, 0.2, 0.0);    // Темно-оранжевый
    vec3 midColor = vec3(1.0, 0.5, 0.1);       // Средний оранжевый  
    vec3 endColor = vec3(1.0, 1.0, 0.3);       // Ярко-желтый
    
    // Двухэтапный градиент
    vec3 color;
    if (gradientFactor < 0.5) {
        color = mix(startColor, midColor, gradientFactor * 2.0);
    } else {
        color = mix(midColor, endColor, (gradientFactor - 0.5) * 2.0);
    }
    
    FragColor = vec4(color, vAlpha * 0.8);
}
`

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

	// Настройки для прозрачности и линий
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	gl.Enable(gl.LINE_SMOOTH)
	gl.LineWidth(3.0)

	program, err := createProgram()
	if err != nil {
		panic(err)
	}

	var vao, vbo uint32
	gl.GenVertexArrays(1, &vao)
	gl.GenBuffers(1, &vbo)

	trail := []point{}
	lastUpdate := time.Now()

	// Получаем текущую позицию курсора для инициализации
	trail = append(trail, point{x: float32(coords[0]), y: float32(coords[1])})

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	go func() { <-stop; win.SetShouldClose(true) }()

	for !win.ShouldClose() {
		// Добавляем точку в хвост чаще
		if time.Since(lastUpdate) > 8*time.Millisecond {
			newPoint := point{x: float32(coords[0]), y: float32(coords[1])}
			// Добавляем точку только если курсор двинулся
			if len(trail) == 0 || (len(trail) > 0 && (newPoint.x != trail[len(trail)-1].x || newPoint.y != trail[len(trail)-1].y)) {
				trail = append(trail, newPoint)
				if len(trail) > 60 {
					trail = trail[1:]
				}
			}
			lastUpdate = time.Now()
		}

		// Конвертация координат в NDC с альфой
		verts := []float32{}
		for i, p := range trail {
			ndcX := (p.x/float32(mode.Width))*2 - 1
			ndcY := (1-p.y/float32(mode.Height))*2 - 1
			// Альфа от 0.1 (старые точки) до 1.0 (новые точки)
			alpha := 0.1 + 0.9*float32(i)/float32(len(trail)-1)
			verts = append(verts, ndcX, ndcY, alpha)
		}

		// Очистка экрана
		gl.ClearColor(0, 0, 0, 0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		// Рисуем только если есть точки
		if len(verts) > 0 {
			gl.BindVertexArray(vao)
			gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
			gl.BufferData(gl.ARRAY_BUFFER, len(verts)*4, gl.Ptr(verts), gl.DYNAMIC_DRAW)
			// Позиция (x, y)
			gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 3*4, gl.PtrOffset(0))
			gl.EnableVertexAttribArray(0)
			// Альфа (прозрачность)
			gl.VertexAttribPointer(1, 1, gl.FLOAT, false, 3*4, gl.PtrOffset(2*4))
			gl.EnableVertexAttribArray(1)

			gl.UseProgram(program)
			gl.DrawArrays(gl.LINE_STRIP, 0, int32(len(trail)))
		}

		win.SwapBuffers()
		glfw.PollEvents()
	}

	C.CFRunLoopStop(C.CFRunLoopGetCurrent())
	fmt.Println("Завершено.")
}
