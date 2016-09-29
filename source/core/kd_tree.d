///
module core.kd_tree;

enum Axis
{
    X,
    Y,
    Z,
    None
}

struct KDTreeNode
{
    Axis axis;
    double splitPos;
    union
    {
        const(int[])*   triangles; // 1 pointer to list of triangle indices
        KDTreeNode[2]*  children;  // 1 pointer to TWO children (children[0] and children[1])
    }

    /// Initialize this node as a leaf node.
    void initLeaf(const int[] triangleList)
    {
        struct Array { size_t len; const int* ptr; }

        axis = Axis.None;
        splitPos = 0;
        triangles = cast(int[]*)new Array(triangleList.length, triangleList.ptr);
    }

    /// Initialize this node as a in-node (a binary node with two children)
    void initBinary(Axis axis, double splitPos)
	{
        axis = axis;
        splitPos = splitPos;
        children = cast(KDTreeNode[2]*)(new KDTreeNode[2]).ptr;
    }

    ~this()
    {
        if (axis == Axis.None)
            delete triangles;
        else
            delete children;
    }
}

import rt.importedtypes : Vector;

