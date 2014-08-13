module rt.rtapp;

interface RTApp
{
	final void run(string[] args = null)
	{
		initScene();
		renderScene();
		displayRenderedImage();
		
		while(handleInput())
		{
			updateScene();
			renderScene();
			displayRenderedImage();
		}
	}
	
	void initScene();
	void updateScene();
	void renderScene();
	void displayRenderedImage();
	bool handleInput();
}