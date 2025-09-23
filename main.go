package main

/*
#cgo LDFLAGS: -framework ApplicationServices -framework Foundation -lobjc
#include <ApplicationServices/ApplicationServices.h>
#include <objc/runtime.h>
#include <objc/message.h>

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

// Функция для получения текущей позиции курсора
CGPoint getCurrentMousePosition() {
    CGEventRef event = CGEventCreate(NULL);
    CGPoint cursor = CGEventGetLocation(event);
    CFRelease(event);
    return cursor;
}

// Функция для настройки прозрачности окна через Objective-C runtime
void makeWindowClickThrough(void* windowPtr) {
    // Получаем класс NSWindow и селектор setIgnoresMouseEvents:
    Class nsWindowClass = objc_getClass("NSWindow");
    SEL setIgnoresMouseEventsSelector = sel_registerName("setIgnoresMouseEvents:");

    // Вызываем [window setIgnoresMouseEvents:YES]
    ((void (*)(id, SEL, BOOL))objc_msgSend)((id)windowPtr, setIgnoresMouseEventsSelector, 1);
}

*/
import "C"
import (
	"fmt"
	"math"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"unsafe"

	"github.com/go-gl/gl/v3.3-core/gl"
	"github.com/go-gl/glfw/v3.3/glfw"
)

type point struct{ x, y float32 }

func init() { runtime.LockOSThread() }

// Функция для вычисления расстояния между двумя точками
func distance(x1, y1, x2, y2 float64) float64 {
	dx := x1 - x2
	dy := y1 - y2
	return math.Sqrt(dx*dx + dy*dy)
}

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
    // Очень широкий и плавный градиент
    float gradientFactor = smoothstep(0.0, 1.0, vAlpha);
    gradientFactor = pow(gradientFactor, 0.15); // Делаем градиент намного шире
    
    // Правильные цвета - яркий цвет для курсора (высокий alpha)
    vec3 startColor = vec3(0.6, 0.1, 0.0);      // Очень темно-оранжевый (для конца хвоста)
    vec3 earlyColor = vec3(0.9, 0.3, 0.0);      // Темно-оранжевый
    vec3 midColor = vec3(1.0, 0.6, 0.1);        // Яркий оранжевый  
    vec3 endColor = vec3(1.0, 1.0, 0.4);        // Ярко-желтый (для курсора)
    
    // Трехэтапный градиент для более плавного перехода
    vec3 color;
    if (gradientFactor < 0.33) {
        color = mix(startColor, earlyColor, gradientFactor * 3.0);
    } else if (gradientFactor < 0.66) {
        color = mix(earlyColor, midColor, (gradientFactor - 0.33) * 3.0);
    } else {
        color = mix(midColor, endColor, (gradientFactor - 0.66) * 3.0);
    }
    
    // Более мягкая прозрачность
    FragColor = vec4(color, vAlpha * 0.9);
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

	// Делаем окно прозрачным для кликов мыши через Objective-C runtime, без этого не можем кликать и совершать действия
	nsWindow := win.GetCocoaWindow()
	C.makeWindowClickThrough(nsWindow)

	win.MakeContextCurrent()
	glfw.SwapInterval(1)

	if err := gl.Init(); err != nil {
		panic(err)
	}

	// Настройки для прозрачности и линий
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	gl.Enable(gl.LINE_SMOOTH)
	gl.LineWidth(2.0) // Временно уменьшаем для диагностики

	program, err := createProgram()
	if err != nil {
		panic(err)
	}

	var vao, vbo uint32
	gl.GenVertexArrays(1, &vao)
	gl.GenBuffers(1, &vbo)

	trail := []point{}

	// Получаем текущую позицию курсора для правильной инициализации
	pos := C.getCurrentMousePosition()
	coords[0] = pos.x
	coords[1] = pos.y
	initialPoint := point{x: float32(coords[0]), y: float32(coords[1])}

	// Добавляем несколько точек в одном месте для плавного начала
	for i := 0; i < 5; i++ {
		trail = append(trail, initialPoint)
	}

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	go func() { <-stop; win.SetShouldClose(true) }()

	frameCounter := 0
	for !win.ShouldClose() {
		// Обновляем координаты курсора на каждом кадре для точности
		pos := C.getCurrentMousePosition()
		coords[0] = pos.x
		coords[1] = pos.y
		currentPoint := point{x: float32(coords[0] + 5), y: float32(coords[1] - 20)}

		trail = append(trail, currentPoint)
		if len(trail) > 80 { // Уменьшим для более короткого хвоста
			trail = trail[1:]
		}
		// Отладочная информация
		frameCounter++
		if len(trail) > 0 {
			headPos := trail[len(trail)-1] // Голова кометы (последняя точка)
			dist := distance(float64(coords[0]), float64(coords[1]), float64(headPos.x), float64(headPos.y))
			//todo сделать этот лог только в режиме дебага
			//логи каждую секунду
			if frameCounter%60 == 0 {
				fmt.Printf("DEBUG: Frame %d | Курсор: (%.1f, %.1f) | Голова: (%.1f, %.1f) | Расстояние: %.1f | Хвост: %d точек\n",
					frameCounter,
					float64(coords[0]), float64(coords[1]),
					float64(headPos.x), float64(headPos.y),
					dist, len(trail))
			}
		}

		// Конвертация координат в NDC с альфой
		verts := []float32{}
		for i, p := range trail {
			ndcX := (p.x/float32(mode.Width))*2 - 1
			ndcY := (1-p.y/float32(mode.Height))*2 - 1
			var alpha float32
			if len(trail) == 1 {
				alpha = 1.0
			} else {
				// Прямой прогресс - последняя точка имеет alpha = 1.0 (самая яркая)
				progress := float32(i) / float32(len(trail)-1)
				alpha = 0.3 + 0.7*progress
			}
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
