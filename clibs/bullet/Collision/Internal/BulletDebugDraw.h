#ifndef __BULLET_ANT_DEBUG_DRAW__
#define __BULLET_ANT_DEBUG_DRAW__

#include "btBulletCollisionCommon.h"
#include "BulletCollision/CollisionShapes/btHeightfieldTerrainShape.h"

#define BT_LINE_BATCH_SIZE 1024
#define UNIT_COLOR

struct MyDebugVec
{
	MyDebugVec(const btVector3& org)
		: x(org.x()),
		  y(org.y()),
		  z(org.z())
	{
	}

	MyDebugVec(const btVector3& org,const btVector3 &color)
		: x(org.x()),
		  y(org.y()),
		  z(org.z())
	{

		#ifdef UNIT_COLOR 
			c =  (uint32_t)(color.z()*255)<<16 | (uint32_t)(color.y()*255)<<8 | (uint32_t)(color.x()*255) ;
		#else 
			c[0] = color.x();
			c[1] = color.y();
			c[2] = color.z();
			c[3] = 1.0f;
		#endif 
	}

	float x;
	float y;
	float z;
#ifdef UNIT_COLOR 	
	uint32_t c;
#else 	
	float c[4];
#endif 

};


typedef void (*Callback_t)();     // any callback what you need . instead of multi renderer,program language 

ATTRIBUTE_ALIGNED16(
class) MyDebugDrawer : public btIDebugDraw
{
    Callback_t  m_debugDrawFunc; 
	int m_debugMode;

    // auto destruct
	btAlignedObjectArray<MyDebugVec> m_linePoints;
	btAlignedObjectArray<unsigned int> m_lineIndices;

	btVector3 m_currentLineColor;
	DefaultColors m_ourColors;

public:
	BT_DECLARE_ALIGNED_ALLOCATOR();

	MyDebugDrawer()
		: m_debugMode(btIDebugDraw::DBG_DrawWireframe /* | btIDebugDraw::DBG_DrawAabb */), m_currentLineColor(-1, -1, -1)
	{
	}

	virtual ~MyDebugDrawer()
	{
	}

	virtual DefaultColors getDefaultColors() const
	{
		return m_ourColors;
	}
	///the default implementation for setDefaultColors has no effect. A derived class can implement it and store the colors.
	virtual void setDefaultColors(const DefaultColors& colors)
	{
		m_ourColors = colors;
	}

	virtual void drawLine(const btVector3& from1, const btVector3& to1, const btVector3& color1)
	{
		if (m_currentLineColor != color1 || m_linePoints.size() >= BT_LINE_BATCH_SIZE)
		{
			flushLines();
			m_currentLineColor = color1;
		}

		MyDebugVec from(from1,color1);
		MyDebugVec to(to1,color1);

		m_linePoints.push_back(from);
		m_linePoints.push_back(to);

		m_lineIndices.push_back(m_lineIndices.size());
		m_lineIndices.push_back(m_lineIndices.size());
	}

	virtual void drawContactPoint(const btVector3& PointOnB, const btVector3& normalOnB, btScalar distance, int lifeTime, const btVector3& color)
	{
		drawLine(PointOnB, PointOnB + normalOnB * distance, color);
		btVector3 ncolor(0, 0, 0);
		drawLine(PointOnB, PointOnB + normalOnB * 0.01, ncolor);
	}

	virtual void reportErrorWarning(const char* warningString)
	{
	}

	virtual void draw3dText(const btVector3& location, const char* textString)
	{
	}

	virtual void setDebugMode(int debugMode)
	{
		m_debugMode = debugMode;
	}

	virtual int getDebugMode() const
	{
		return m_debugMode;
	}

	virtual void flushLines()
	{
		 int sz = m_linePoints.size();
		if (sz) // && m_debugDrawFunc )  -- if wanna callback mode, open it
		{
			// float debugColor[4];
			// debugColor[0] = m_currentLineColor.x();
			// debugColor[1] = m_currentLineColor.y();
			// debugColor[2] = m_currentLineColor.z();
			// debugColor[3] = 1.f;

            // m_debugDrawFunc(&m_linePoints[0].x, debugColor,
			// 			    m_linePoints.size(), sizeof(MyDebugVec3),
			// 			    &m_lineIndices[0],
			// 			    m_lineIndices.size(),
			// 			    1);
			//m_linePoints.clear();
			//m_lineIndices.clear();
		} 
	}

	virtual void reset() {
		m_linePoints.clear();
		m_lineIndices.clear();
	}

	float *getVertices(int &size) const 
	{
		size = m_linePoints.size();
		if(size)
			return (float *) &m_linePoints[0].x;
		else 
			return nullptr;
	}

	unsigned int *getIndices(int &size) const 
	{
		size = m_lineIndices.size();
		if(size)
		  return (unsigned int*) &m_lineIndices[0];
		else
		  return nullptr;
	}

};

/*
function debugDraw(bgfx,vb,ib)
	self:create_vdecl( vd )
	self.data  = lterrain.create(self.heightmap,args,self.render_ctx.vdecl)
	self.vbo   = self.data:allocVB()
	self.ibo   = self.data:allocIB()

	lterrain.update_mesh( self.data,self.vbo,self.ibo) 

	local num = self.data:getNumVerts()
	self.render_ctx.vbh = bgfx.create_dynamic_vertex_buffer( num, self.render_ctx.vdecl );
	bgfx.update( self.render_ctx.vbh, 0, {'!',self.vbo} )

	num = self.data:getNumIndices()
	self.render_ctx.ibh = bgfx.create_dynamic_index_buffer( num,"rwd" )
	bgfx.update( self.render_ctx.ibh, 0, {self.ibo} )
end 
*/
/*
void GLInstancingRenderer::drawLines(const float* positions, const float color[4], int numPoints, int pointStrideInBytes, const unsigned int* indices, int numIndices, float lineWidthIn)
{
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, 0);

	float lineWidth = lineWidthIn;
	b3Clamp(lineWidth, (float)lineWidthRange[0], (float)lineWidthRange[1]);
	glLineWidth(lineWidth);

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, 0);

	b3Assert(glGetError() == GL_NO_ERROR);
	glUseProgram(linesShader);
	glUniformMatrix4fv(lines_ProjectionMatrix, 1, false, &m_data->m_projectionMatrix[0]);
	glUniformMatrix4fv(lines_ModelViewMatrix, 1, false, &m_data->m_viewMatrix[0]);
	glUniform4f(lines_colour, color[0], color[1], color[2], color[3]);

	//	glPointSize(pointDrawSize);
	glBindVertexArray(linesVertexArrayObject);

	b3Assert(glGetError() == GL_NO_ERROR);
	glBindBuffer(GL_ARRAY_BUFFER, linesVertexBufferObject);

	{
		glBufferData(GL_ARRAY_BUFFER, numPoints * pointStrideInBytes, 0, GL_DYNAMIC_DRAW);

		glBufferSubData(GL_ARRAY_BUFFER, 0, numPoints * pointStrideInBytes, positions);
		b3Assert(glGetError() == GL_NO_ERROR);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
		glBindBuffer(GL_ARRAY_BUFFER, linesVertexBufferObject);
		glEnableVertexAttribArray(0);

		b3Assert(glGetError() == GL_NO_ERROR);
		int numFloats = 3;
		glVertexAttribPointer(0, numFloats, GL_FLOAT, GL_FALSE, pointStrideInBytes, 0);
		b3Assert(glGetError() == GL_NO_ERROR);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, linesIndexVbo);
		int indexBufferSizeInBytes = numIndices * sizeof(int);

		glBufferData(GL_ELEMENT_ARRAY_BUFFER, indexBufferSizeInBytes, NULL, GL_DYNAMIC_DRAW);
		glBufferSubData(GL_ELEMENT_ARRAY_BUFFER, 0, indexBufferSizeInBytes, indices);

		glDrawElements(GL_LINES, numIndices, GL_UNSIGNED_INT, 0);
	}

	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	//	for (int i=0;i<numIndices;i++)
	//		printf("indicec[i]=%d]\n",indices[i]);
	b3Assert(glGetError() == GL_NO_ERROR);
	glBindVertexArray(0);
	b3Assert(glGetError() == GL_NO_ERROR);
	glPointSize(1);
	b3Assert(glGetError() == GL_NO_ERROR);
	glUseProgram(0);
}
*/

#endif 
