#pragma once

#include "gui/GLView.h"
#include "renderer/renderer.h"

#include <QOpenGLFramebufferObject>

#include <memory>


class QOpenGLFramebufferObject;

/**
 * Grab the of the Tree element that was rendered at a specific location
 */
class MouseSelector
{
public:
	MouseSelector(GLView *view);

	/// Resize the renderbuffer
	void reset(GLView *view);

	int select(const Renderer *renderer, int x, int y);

	GLView::shaderinfo_t shaderinfo;

private:
	void init_shader();
	void setup_framebuffer(const GLView *view);

	std::unique_ptr<QOpenGLFramebufferObject> framebuffer;

	GLView *view;
};
