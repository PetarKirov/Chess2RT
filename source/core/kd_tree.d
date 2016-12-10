///
module core.kd_tree;

import core.axis : Axis;

struct KDTreeNode
{
    Axis axis;
    double splitPos;
    union
    {
        const(uint[])* triangles; // 1 pointer to list of triangle indices
        KDTreeNode[2]* children;  // 1 pointer to TWO children (children[0] and children[1])
    }

    /// Initialize this node as a leaf node.
    void initLeaf(const uint[] triangleList)
    {
        struct Array { size_t len; const uint* ptr; }

        this.axis = Axis.None;
        this.splitPos = 0;
        this.triangles = cast(uint[]*)new Array(triangleList.length, triangleList.ptr);
    }

    /// Initialize this node as a in-node (a binary node with two children)
    void initBinary(Axis axis, double splitPos)
	{
        this.axis = axis;
        this.splitPos = splitPos;
        this.children = cast(KDTreeNode[2]*)(new KDTreeNode[2]).ptr;
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

