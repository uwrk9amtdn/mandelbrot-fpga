#include <Hd.h>

#include <Vwrapper_top.h>

#include <functional>
#include <stdexcept>
#include <thread>

int main() {
    auto& window = Hd::Window::getInstance();
    Hd::Gui gui(&window);
    window.fpsLimit(60);

    {
        auto& style = ImGui::GetStyle();
        style.FrameRounding = 10.0f;
        style.WindowRounding = 10.0f;
        style.FrameBorderSize = 1.0f;
        style.WindowBorderSize = 1.0f;

        auto f = Hd::Resource::getLibRes("res/fonts/ElenaWebRegular.ttf");
        auto data = std::make_unique<char[]>(f.second);
        std::memcpy(data.get(), f.first, f.second);
        ImGui::GetIO().Fonts->AddFontFromMemoryTTF(data.release(), f.second, 30);
    }

    VerilatedContext con;
    // con.traceEverOn(true);

    Vwrapper_top top(&con);

    std::atomic<bool> run = false;
    std::atomic<bool> join = false;

    std::atomic<int>   max_it;
    std::atomic<float> center_x;
    std::atomic<float> center_y;
    std::atomic<float> xy_step;

    int   gui_max_it = 0;
    float gui_center_x = 0;
    float gui_center_y = 0;
    float gui_xy_step = 0;

    int tex_w = 2048;
    int tex_h = 2048;

    std::vector<uint> iter;
    iter.resize(tex_w * tex_h);

    auto f = [&] {
        top.clk          = 0;
        top.rst          = 1;
        top.s_valid      = 0;
        top.s_max_it     = 0;
        top.s_center_x   = 0;
        top.s_center_y   = 0;
        top.s_xy_step    = 0;
        top.m_addr_ready = 0;
        top.m_data_ready = 0;
        top.eval();
        con.timeInc(1);

        for (int i = 0; i < 10; i++) {
            top.clk = 1;
            top.eval();
            con.timeInc(1);
            top.clk = 0;
            top.eval();
            con.timeInc(1);
        }
        top.rst = 0;

        top.m_addr_ready = 1;
        top.m_data_ready = 1;

        uint last_addr;
        std::vector<uint> data;

        while (!join) {
            top.clk = 1;
            top.eval();

            if (top.s_valid) {
                if (top.s_ready) {
                    top.s_valid = 0;
                    run = false;
                }
            } else {
                if (run) {
                    top.s_valid      = 1;
                    top.s_max_it     = max_it;
                    top.s_center_x   = center_x * (1 << 16);
                    top.s_center_y   = center_y * (1 << 16);
                    top.s_xy_step    = xy_step * (1 << 16);
                }
            }

            if (top.m_addr_valid) {
                last_addr = top.m_addr_data;
                if (last_addr > tex_w * tex_h * 2) {
                    throw std::runtime_error("ADDR ERROR");
                }
            }

            if (top.m_data_valid) {
                data.push_back(top.m_data_data);
                if (top.m_data_last) {
                    std::memcpy((char*)(&iter[0]) + last_addr * 2, &data[0], data.size() * sizeof(uint));
                    // printf("DATA WRITE, addr = %d, data.size = %d\n", last_addr, data.size());
                    data = {};
                }
            }

            con.timeInc(1);

            top.clk = 0;
            top.eval();
            con.timeInc(1);
        }
    };

    std::thread t(f);

    // input  logic clk,
    // input  logic rst,

    // output logic         s_ready,
    // input  logic         s_valid,
    // input  logic [15:0]  s_max_it,
    // input  logic [2:-16] s_center_x,
    // input  logic [2:-16] s_center_y,
    // input  logic [2:-16] s_xy_step,

    // input  logic         m_addr_ready,
    // output logic         m_addr_valid,
    // output logic [31:0]  m_addr_data,

    // input  logic         m_data_ready,
    // output logic         m_data_valid,
    // output logic [15:0]  m_data_data,
    // output logic         m_data_last


    for (int i = 0; i < tex_w; i++) {
        for (int j = 0; j < tex_h; j++) {
            // iter[i * tex_w + j] = random() % 100;
            if (i == j) {
                iter[i*tex_w + j] = 100;
            }
        }
    }

    int shader_max_it = 100;

    auto tex    = Hd::Texture::emptyTexture(4096, 4096);
    auto fb     = Hd::FrameBuffer(tex);
    auto shader = Hd::Shader(Hd::Resource::getExeRes("res/shaders/vertex.glsl").first, Hd::Resource::getExeRes("res/shaders/fragment.glsl").first);

    Hd::VAO vao;

    Hd::SSBO ssbo;
    ssbo.Data(&iter[0], sizeof(uint) * iter.size(), GL_DYNAMIC_DRAW);

    glm::vec2 image_size = {tex_w, tex_h};

    auto guifunc = [&]{
        using namespace ImGui;
        ShowDemoWindow();
        auto s = window.getFramebufferSize();
        SetNextWindowPos({0, 0});
        SetNextWindowSize({s.x, s.y});
        auto flags = ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoBringToFrontOnFocus;
        Begin("Mandelbrot", 0, flags);

        {
            bool b = run;
            if (b) BeginDisabled();
            BeginChild("Settings", {500, 0}, ImGuiChildFlags_Borders);

            SliderInt("Max It", &gui_max_it, 0, 4096);
            SliderFloat("Center X", &gui_center_x, -2.0f, 2.0f);
            SliderFloat("Center Y", &gui_center_y, -2.0f, 2.0f);
            SliderFloat("XY Step", &gui_xy_step, 0.0f, 0.1f, "%.6f");

            if (Button("Run")) {
                max_it   = gui_max_it;
                center_x = gui_center_x;
                center_y = gui_center_y;
                xy_step  = gui_xy_step;
                run      = true;
            }

            if (b) EndDisabled();

            Separator();

            SliderInt("Shader Max It", &shader_max_it, 0, 4096);

            EndChild();
        }

        SameLine();

        {
            BeginChild("FrameBuffer", {0, 0}, ImGuiChildFlags_Borders);

            auto s = GetContentRegionAvail();
            auto c = GetCursorPos();

            float scale = std::min(s.x / tex_w, s.y / tex_h);
            image_size = {tex_w * scale, tex_h * scale};

            SetCursorPos({(c.x + (s.x - image_size.x) * 0.5f), (c.y + (s.y - image_size.y) * 0.5f)});
            Image(tex.Id(), {tex_w*scale, tex_h*scale}, {0.0, 0.0}, {image_size.x / 4096.0f, image_size.y / 4096.0f});

            EndChild();
        }


        End();
    };

    gui.Functions.add(guifunc);

    while (!window.ShouldClose()) {
        window.PollEvents();

        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glViewport(0, 0, window.getFramebufferSize().x, window.getFramebufferSize().y);
        glBindVertexArray(0);
        glClearColor(0, 0, 0, 0);
        glClear(GL_COLOR_BUFFER_BIT);

        ssbo.SubData(&iter[0], 0, sizeof(uint) * iter.size());

        fb.Bind();
        glViewport(0, 0, image_size.x, image_size.y);
        vao.Bind();
        ssbo.BindBase(3);
        shader.Bind();
        glUniform1ui(1, shader_max_it);
        glUniform1ui(2, tex_w);
        glUniform1ui(3, tex_h);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glViewport(0, 0, window.getFramebufferSize().x, window.getFramebufferSize().y);
        glBindVertexArray(0);

        gui.Draw();

        window.SwapBuffers();
    }

    join = true;
    t.join();
}